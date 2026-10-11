//
//  HomeView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-08.
//

import SwiftUI

struct HomeView: View {
    @Environment(SubscriptionStore.self) private var store
    
    var body: some View {
        NavigationStack {
            Text(store.isSubscribed ? "Premium unlocked" : "Premium locked")
                .navigationTitle("StreamLab")
        }
    }
}
