//
//  AccountView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-08.
//

import SwiftUI
import StoreKit

struct AccountView: View {
    
    @Environment(SubscriptionStore.self) private var store
    
    var body: some View {
        NavigationStack {
            List {
                Section("Plans") {
                    ForEach(store.products) { product in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.displayName)
                                .font(.headline)
                            Text(product.description)
                                .foregroundStyle(.secondary)
                            Text(product.displayPrice)
                            
                            if let intro = product.subscription?.introductoryOffer {
                                Text("Intro: \(intro.period.value) \(intro.period.unit.localizedDescription), \(intro.displayPrice)")
                                    .foregroundStyle(.green)
                            }
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
        }
    }
}


#Preview {
    RootView()
        .environment(SubscriptionStore())
}
