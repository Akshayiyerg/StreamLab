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
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
