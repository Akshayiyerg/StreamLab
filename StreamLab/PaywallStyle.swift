//
//  PaywallStyle.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-20.
//

import SwiftUI

enum PaywallStyle: String, CaseIterable, Identifiable {
    case custom
    case storeKit
    
    static let storageKey = "paywallStyle"
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .custom: "Custom"
        case .storeKit: "StoreKit view"
        }
    }
}

struct PaywallSheet: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage(PaywallStyle.storageKey) private var style = PaywallStyle.custom
    @State private var showAllPlans = false
    
    var body: some View {
        switch style {
        case .custom:
            if let winBack = store.winBackOffer, !showAllPlans {
                WinBackOfferView(winBack: winBack) {
                    showAllPlans = true
                }
            } else {
                PaywallView()
            }
        case .storeKit:
            StoreKitPaywallView()
        }
    }
}
