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
    @State private var message: String?
    @State private var showPaywall = false
    @AppStorage(PaywallStyle.storageKey) private var paywallStyle = PaywallStyle.custom
    
    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    if let activeID = store.activeProductID {
                        let planName = store.products.first(where: { $0.id == activeID})?.displayName ?? "Active"
                        Label("Premium: \(planName)", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Free Plan", systemImage: "lock.fill")
                    }
                }
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
                            
                            Button("Subscribe") {
                                Task {
                                    do {
                                        let outcome = try await store.purchase(product)
                                        message = "\(product.displayName): \(outcome)"
                                    } catch {
                                        message = "Failed: \(error.localizedDescription)"
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(store.activeProductID == product.id)
                        }
                    }
                }
                
                if let message {
                    Section("Last purchase") {
                        Text(message)
                    }
                }
                
                Section("Developer options") {
                    Picker("Paywall style", selection: $paywallStyle) {
                        ForEach(PaywallStyle.allCases) {
                            style in
                            Text(style.title).tag(style)
                        }
                    }
                    
                    Button("Show paywall") {
                        showPaywall = true
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
        }
    }
}


#Preview {
    RootView()
        .environment(SubscriptionStore())
        .modelContainer(for: CachedVideo.self, inMemory: true)
}
