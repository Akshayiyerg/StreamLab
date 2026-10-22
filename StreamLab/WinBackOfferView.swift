//
//  WinBackOfferView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-21.
//

import SwiftUI
import StoreKit

struct WinBackOfferView: View {
    let winBack: WinBackOffer
    let onShowAllPlans: () -> Void
    
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.pink)
                    
                    Text("Welcome back")
                        .font(.largeTitle.bold())
                    
                    Text("Here's a special offer to rejoin StreamLab Premium.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 6) {
                        Text(winBack.product.displayName)
                            .font(.headline)
                        Text(offerText)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.background.secondary, in: .rect(cornerRadius: 12))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.background.secondary, in: .rect(cornerRadius: 12))
                
                Button {
                    Task { await claim() }
                } label: {
                    Group {
                        if isPurchasing {
                            ProgressView()
                        } else {
                            Text("Claim offer")
                                .bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isPurchasing)
                
                Button("See all plans", action: onShowAllPlans)
                
                Text("After the offer, your subscription renews automatically at \(winBack.product.pricePerPeriod) unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple Account settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Link("Privacy Policy", destination: URL(string: "https://github.com/Akshayiyerg/StreamLab/blob/main/PRIVACY.md")!)
                }
                .font(.footnote)
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
        .alert("Purchase failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var offerText: String {
        let offer = winBack.offer
        let total = offer.period.value * offer.periodCount
        let unit = offer.period.unitName
        let span = total == 1 ? "your first \(unit)" : "your first \(total) \(unit)s"
        let after = "then \(winBack.product.pricePerPeriod)"
        
        switch offer.paymentMode {
        case .freeTrial:
            return "Free for \(span), \(after)."
        case .payUpFront:
            return "\(offer.displayPrice) for \(span), \(after)."
        default:
            return "\(offer.displayPrice)/\(offer.period.recurringText) for \(span), \(after)."
        }
    }
    
    private func claim() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            if try await store.purchase(winBack.product, winBackOffer: winBack.offer) == .success {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

