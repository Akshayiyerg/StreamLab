//
//  AccountView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-08.
//

import SwiftUI
import StoreKit
import SwiftData

struct AccountView: View {
    
    @Environment(SubscriptionStore.self) private var store
    
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false
    @State private var showOfferCode = false
    @State private var restoreMessage: String?
    @AppStorage(PaywallStyle.storageKey) private var paywallStyle = PaywallStyle.custom
    
    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                manageSection
                
                Section("Developer options") {
                    Picker("Paywall style", selection: $paywallStyle) {
                        ForEach(PaywallStyle.allCases) {
                            style in
                            Text(style.title).tag(style)
                        }
                    }
                }
                
                if let error = store.loadError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Account")
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
            .manageSubscriptionsSheet(
                isPresented: $showManageSubscriptions,
                subscriptionGroupID: store.subscriptionGroupID ?? ""
            )
            .offerCodeRedemption(isPresented: $showOfferCode)
            .alert("Restore Purchase", isPresented: Binding(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var subscriptionSection: some View {
        Section("Subscription") {
            if !store.hasLoadedEntitlements {
                HStack {
                    ProgressView()
                    Text("Checking subscription...")
                        .foregroundStyle(.secondary)
                }
            } else if let details = store.details {
                Label("Premium: \(store.planName(for: details.productID))", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                
                if details.isFreeTrail {
                    Label("Free trial", systemImage: "gift")
                }
                
                if details.state == .inBillingRetryPeriod || details.state == .inGracePeriod {
                    Label("There's a problem with your payment method. Update it to keep Premium.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                
                if let date = details.expirationDate {
                    Text(renewalText(for: details, date: date))
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("Free plan", systemImage: "lock.fill")
                
                Button("See Premium plans") {
                    showPaywall = true
                }
            }
        }
    }
    
    private var manageSection: some View {
        Section {
            if store.details != nil {
                Button("Manage Subscription") {
                    showManageSubscriptions = true
                }
            }
            
            Button("Restore Purchases") {
                Task { await restore() }
            }
            
            Button("Redeem offer Code") {
                showOfferCode = true
            }
        }
    }
    
    // MARK: - Helpers
    
    private func renewalText(for details: SubscriptionDetails, date: Date) -> String {
        let formatted = date.formatted(date: .abbreviated, time: .shortened)
        
        guard details.willAutoRenew else {
            return "Cancelled. Access ends \(formatted)"
        }
        
        if let next = details.nextProductID, next != details.productID {
            return "Switches to \(store.planName(for: next)) on \(formatted)"
        }
        
        return "Renews \(formatted)"
    }
    
    private func restore() async {
        do {
            try await store.restore()
            restoreMessage = store.isSubscribed
            ? "Your subscription has been restored."
            : "No active subscription was found for this Apple Account."
        } catch {
            restoreMessage = error.localizedDescription
        }
    }
}


#Preview {
    RootView()
        .environment(SubscriptionStore())
        .modelContainer(for: CachedVideo.self, inMemory: true)
}
