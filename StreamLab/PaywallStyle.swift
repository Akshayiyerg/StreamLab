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
    @AppStorage(PaywallStyle.storageKey) private var style = PaywallStyle.custom
    
    var body: some View {
        switch style {
        case .custom:
            PaywallView()
        case .storeKit:
            StoreKitPaywallView()
        }
    }
}
