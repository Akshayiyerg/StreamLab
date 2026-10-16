//
//  SubscriptionStore.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-09.
//


import StoreKit
import Observation


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
    
    var isSubscribed: Bool {
        activeProductID != nil
    }
    
    func canWatch(isPremium: Bool) -> Bool {
        !isPremium || isSubscribed
    }
    
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    
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
    }
    
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        
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
