//
//  VideoDetailView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-16.
//

import SwiftUI

struct VideoDetailView: View {
    let video: CachedVideo
    
    @Environment(SubscriptionStore.self) private var store
    @State private var showPlayer = false
    @State private var showPlans = false
    
    private var canWatch: Bool {
        store.canWatch(isPremium: video.isPremium)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PosterView(category: video.category)
                    .frame(height: 220)
                    .clipShape(.rect(cornerRadius: 16))
                
                Text(video.title)
                    .font(.largeTitle.bold())
                
                Text("\(video.category) · \(video.durationMinutes) min\(video.isPremium ? " · Premium" : "")")
                    .foregroundStyle(.secondary)
                
                Button {
                    if canWatch {
                        showPlayer = true
                    } else {
                        showPlans = true
                    }
                } label: {
                    Label(canWatch ? "Play" : "Unlock with Premium", systemImage: canWatch ? "Play.fill" : "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Text(video.synopsis)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(url: video.streamURL, isPremium: video.isPremium)
        }
        .sheet(isPresented: $showPlans) {
            AccountView()
        }
        .onChange(of: store.isSubscribed) {
            if store.isSubscribed {
                showPlans = false
            }
        }
    }
}
