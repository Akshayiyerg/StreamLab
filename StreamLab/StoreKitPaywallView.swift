//
//  StoreKitPaywallView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-20.
//


import SwiftUI
import StoreKit

struct StoreKitPaywallView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var errorMessage: String?
    
    var body: some View {
        SubscriptionStoreView(productIDs: ProductID.all) {
            VStack(spacing: 12) {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("StreamLab Premium")
                    .font(.largeTitle.bold())
                Text("Every title in the catalogue. Cancel anytime.")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding()
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        .storeButton(.visible, for: .policies)
        .subscriptionStorePolicyDestination(url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!,
        for: .termsOfService
        )
        .subscriptionStorePolicyDestination(url: URL(string: "https://github.com/Akshayiyerg/StreamLab/blob/main/PRIVACY.md")!, for: .privacyPolicy
        )
        .onInAppPurchaseCompletion { _, result in
            switch result {
            case .success(let purchaseResult):
                do {
                    if try await store.process(purchaseResult) == .success {
                        dismiss()
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("Purchase failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
