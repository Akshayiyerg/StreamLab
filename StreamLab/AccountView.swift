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
                
                #if DEBUG
                Section("Developer options") {
                    Picker("Paywall style", selection: $paywallStyle) {
                        ForEach(PaywallStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                }
                #endif
                
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
            .alert("Restore Purchases", isPresented: Binding(
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
                LabeledContent("Plan", value: store.planName(for: details.productID))
                
                LabeledContent("Status") {
                    Text(statusText(for: details))
                        .foregroundStyle(statusColor(for: details))
                }
                
                if let date = details.expirationDate {
                    LabeledContent(dateLabel(for: details), value: date.formatted(date: .abbreviated, time: .omitted))
                }
                
                if let next = nextPlanText(for: details) {
                    LabeledContent("Then", value: next)
                }
                
                if details.state == .inBillingRetryPeriod || details.state == .inGracePeriod {
                    Label("There's a problem with your payment method. Update it to keep Premium.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
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
            
            Button("Redeem Offer Code") {
                showOfferCode = true
            }
        }
    }
    
    // MARK: - Helpers
    
    private func statusText(for details: SubscriptionDetails) -> String {
        switch details.state {
        case .inBillingRetryPeriod: return "On hold"
        case .inGracePeriod: return "Payment issue"
        default: break
        }
        
        if !details.willAutoRenew { return "Cancelled" }
        return details.isFreeTrial ? "Free trial" : "Active"
    }
    
    private func statusColor(for details: SubscriptionDetails) -> Color {
        if details.state == .inBillingRetryPeriod || details.state == .inGracePeriod {
            return .orange
        }
        return details.willAutoRenew ? .green : .secondary
    }
    
    private func dateLabel(for details: SubscriptionDetails) -> String {
        if !details.willAutoRenew { return "Access ends" }
        return details.isFreeTrial ? "Trial ends" : "Renews"
    }
    
    private func nextPlanText(for details: SubscriptionDetails) -> String? {
        guard details.willAutoRenew else { return nil }
        
        let nextID = details.nextProductID ?? details.productID
        guard nextID != details.productID || details.isFreeTrial, let next = store.products.first(where: { $0.id == nextID }) else { return nil }
        
        return "\(next.displayName), \(next.pricePerPeriod)"
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
