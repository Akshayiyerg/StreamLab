//
//  SubscriptionStore.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-09.
//


import StoreKit
import Observation

@MainActor
@Observable
final class SubscriptionStore {
    
    private(set) var products: [Product] = []
    private(set) var loadError: String?
    
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
}
