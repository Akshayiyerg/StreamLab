//
//  SubscriptionStore.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-09.
//


import StoreKit
import Observation


struct SubscriptionDetails {
    let productID: String
    let state: Product.SubscriptionInfo.RenewalState
    let expirationDate: Date?
    let willAutoRenew: Bool
    let nextProductID: String?
    let isFreeTrial: Bool
}

struct WinBackOffer {
    let product: Product
    let offer: Product.SubscriptionOffer
}

enum PurchaseOutcome {
    case success
    case cancelled
    case pending
}


@MainActor
@Observable
final class SubscriptionStore {
    
    private(set) var products: [Product] = []
    private(set) var loadError: String?
    private(set) var activeProductID: String?
    private(set) var isEligibleForTrial = false
    
    private(set) var details: SubscriptionDetails?
    private(set) var hasLoadedEntitlements = false
    private(set) var winBackOffer: WinBackOffer?
    
    var isSubscribed: Bool {
        activeProductID != nil
    }
    
    var subscriptionGroupID: String? {
        products.first?.subscription?.subscriptionGroupID
    }
    
    func planName(for productID: String) -> String {
        products.first { $0.id == productID }?.displayName ?? "Premium"
    }
    
    func canWatch(isPremium: Bool) -> Bool {
        !isPremium || isSubscribed
    }
    
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    
    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        
        statusTask = Task { [weak self] in
            
            for await _ in Product.SubscriptionInfo.Status.updates {
                await self?.refreshEntitlements()
            }
        }
    }
    
    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = loaded.sorted { $0.price < $1.price }
            loadError = loaded.isEmpty ? "No products found. Check the scheme's StoreKit Configuration."
            : nil
        } catch {
            loadError = error.localizedDescription
        }
    }
    
    func refreshEntitlements() async {
        var active: String?
        
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            
            if transaction.productType == .autoRenewable {
                active = transaction.productID
            }
        }
        
        activeProductID = active
        await refreshTrialEligibility()
        
        await refreshDetails()
        scheduleExpiryRefresh(at: details?.expirationDate)
        hasLoadedEntitlements = true
    }
    
    func refreshTrialEligibility() async {
        guard let subscription = products.first?.subscription else { return }
        isEligibleForTrial = await subscription.isEligibleForIntroOffer
    }
    
    func refreshDetails() async {
        guard let subscription = products.first?.subscription,
              let statuses = try? await subscription.status else {
            details = nil
            winBackOffer = nil
            return
        }
        
        winBackOffer = findWinBackOffer(in: statuses)
        
        let activeStates: [Product.SubscriptionInfo.RenewalState] = [.subscribed, .inGracePeriod, .inBillingRetryPeriod]
        
        guard let status = statuses.first(where: { activeStates.contains($0.state) }),
              let transaction = try? checkVerified(status.transaction),
              let renewalInfo = try? checkVerified(status.renewalInfo) else {
            details = nil
            return
        }
        
        details = SubscriptionDetails(
            productID: transaction.productID,
            state: status.state,
            expirationDate: transaction.expirationDate,
            willAutoRenew: renewalInfo.willAutoRenew,
            nextProductID: renewalInfo.autoRenewPreference,
            isFreeTrial: transaction.offer?.paymentMode == .freeTrial
        )
    }
    
    private func scheduleExpiryRefresh(at date: Date?) {
        expiryTask?.cancel()
        guard let date, date > .now else { return }
        
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(date.timeIntervalSinceNow + 1))
            guard !Task.isCancelled else { return }
            await self?.refreshEntitlements()
        }
    }
    
    private func findWinBackOffer(in statuses: [Product.SubscriptionInfo.Status]) -> WinBackOffer? {
        let activeStates: [Product.SubscriptionInfo.RenewalState] = [.subscribed, .inGracePeriod, .inBillingRetryPeriod]
        guard !statuses.contains(where: { activeStates.contains($0.state) }) else { return nil }
        
        for status in statuses where status.state == .expired {
            guard let renewalInfo = try? checkVerified(status.renewalInfo) else { continue }
            
            for offerID in renewalInfo.eligibleWinBackOfferIDs {
                for product in products {
                    if let offer = product.subscription?.winBackOffers.first(where: { $0.id == offerID }) {
                        return WinBackOffer(product: product, offer: offer)
                    }
                }
            }
        }
        
        return nil
    }
    
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }
    
    func purchase(_ product: Product, winBackOffer offer: Product.SubscriptionOffer? = nil) async throws -> PurchaseOutcome {
        var options: Set<Product.PurchaseOption> = []
        if let offer {
            options.insert(.winBackOffer(offer))
        }
        
        let result = try await product.purchase(options: options)
        return try await process(result)
    }
    
    func process(_ result: Product.PurchaseResult) async throws -> PurchaseOutcome {
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshEntitlements()
            await transaction.finish()
            return .success
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }
    
    private func handle(_ result:VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(result) else { return }
        
        print("Transaction update:", transaction.productID, "revoked:", transaction.revocationDate != nil)
        
        await refreshEntitlements()
        await transaction.finish()
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
