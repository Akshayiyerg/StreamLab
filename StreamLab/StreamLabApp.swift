//
//  StreamLabApp.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-08.
//

import SwiftUI

@main
struct StreamLabApp: App {
    
    @State private var store = SubscriptionStore()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task {
                    await store.loadProducts()
                }
        }
    }
}
