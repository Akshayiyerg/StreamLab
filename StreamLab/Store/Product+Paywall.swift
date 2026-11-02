//
//  Product+Paywall.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-19.
//

import StoreKit

extension Product {
    var pricePerPeriod: String {
        guard let period = subscription?.subscriptionPeriod else { return displayPrice }
        return "\(displayPrice)/\(period.recurringText)"
    }
}

extension Product.SubscriptionPeriod {
    var unitName: String {
        switch unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        @unknown default: "period"
        }
    }
    
    var recurringText: String {
        value == 1 ? unitName : "\(value) \(unitName)s"
    }
    
    var trialText: String {
        switch unit {
        case .day: "\(value)-day"
        case .week: "\(value * 7)-day"
        default: "\(value)-\(unitName)"
        }
    }
}
