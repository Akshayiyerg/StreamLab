//
//  PaywallView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-19.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedID = ProductID.annual
    @State private var isPurchasing = false
    @State private var alertTitle = ""
    @State private var alertMessage: String?
    
    private var monthly: Product? { store.products.first { $0.id == ProductID.monthly } }
    private var annual: Product? { store.products.first { $0.id == ProductID.annual } }
    private var selected: Product? { store.products.first { $0.id == selectedID } }
    
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    plans
                    subscribeButton
                    finePrint
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }
    
    // MARK: - Sections
    
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.tv.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            
            Text("StreamLab Premium")
                .font(.largeTitle.bold())
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Every title in the catalogue", systemImage: "flim.stack")
                Label("New premium releases", systemImage: "sparkles")
                Label("Cancel anytime", systemImage: "checkmark.circle")
            }
        }
    }
    
    private var plans: some View {
        VStack(spacing: 12) {
            if let annual {
                PlanCard(
                    product: annual,
                    isSelected: selectedID == annual.id,
                    badge: savingsBadge,
                    detail: "\((annual.price / 12).formatted(annual.priceFormatStyle))/month, billed yearly"
                ) {
                    selectedID = annual.id
                }
            }
            
            if let monthly {
                PlanCard(
                    product: monthly,
                    isSelected: selectedID == monthly.id,
                    badge: nil,
                    detail: trialText(for: monthly)
                ) {
                    selectedID = monthly.id
                }
            }
        }
    }
    
    private var subscribeButton: some View {
        Button {
            Task { await buy() }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                } else {
                    Text(buttonTitle)
                        .bold()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selected == nil || isPurchasing)
    }
    
    private var finePrint: some View {
        VStack(spacing: 12) {
            Text(termsText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("Restore Purchases") {
                    Task { await restore() }
                }
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy", destination: URL(string: "https://github.com/Akshayiyerg/StreamLab/blob/main/PRIVACY.md")!)
            }
            .font(.footnote)
        }
    }
    
    // MARK: - Text
    
    private var savingsBadge: String? {
        guard let monthly, let annual else { return nil }
        let yearlyAtMonthlyPrice = monthly.price * 12
        guard yearlyAtMonthlyPrice > 0 else { return nil }
        let saving = (1 - annual.price / yearlyAtMonthlyPrice ) * 100
        let percent = Int(NSDecimalNumber(decimal: saving).doubleValue.rounded())
        return percent > 0 ? "Save \(percent)%" : nil
    }
    
    private func trialText(for product: Product) -> String? {
        guard store.isEligibleForTrial,
              let intro = product.subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else { return nil }
        return "\(intro.period.trialText) free trial"
    }
    
    private var buttonTitle: String {
        guard let selected else { return "Subscribe" }
        if let trial = trialText(for: selected) {
            return "Start \(trial)"
        }
        return "Subscribe for \(selected.pricePerPeriod)"
    }
    
    private var termsText: String {
        guard let selected else { return "" }
        var text = ""
        if let trial = trialText(for: selected) {
            text += "After your \(trial), you'll be charged \(selected.pricePerPeriod). "
        }
        text += "Payment is charged to your Apple Account. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel it anytime in your Apple Account settings."
        return text
    }
    
    // MARK: - Actions
    
    private func buy() async {
        guard let selected else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            switch try await store.purchase(selected) {
            case .success:
                dismiss()
            case .pending:
                showAlert("Waiting for approval", "You'll get access as soon as the purchase is approved.")
            case .cancelled:
                break
            }
        } catch {
            showAlert("Purchase failed", error.localizedDescription)
        }
    }
    
    private func restore() async {
        do {
            try await store.restore()
            if store.isSubscribed {
                dismiss()
            } else {
                showAlert("Nothing to restore", "No active subscription was found for this Apple Account.")
            }
        } catch {
            showAlert("Restore failed", error.localizedDescription)
        }
    }
    
    private func showAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
    }
}

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let detail: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.green, in: .capsule)
                                .foregroundStyle(.white)
                        }
                    }
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(product.pricePerPeriod)
                    .font(.headline)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding()
            .background(.background.secondary, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
