//
//  HomeView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-08.
//

import SwiftUI

struct HomeView: View {
    @Environment(SubscriptionStore.self) private var store
    
    @State private var videos: [Video] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let service = CatalogService()
    
    var body: some View {
        NavigationStack {
            List(videos) { video in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.headline)
                        Text("\(video.category) · \(video.durationMinutes) min")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if video.isPremium && !store.isSubscribed {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if isLoading && videos.isEmpty {
                    ProgressView()
                } else if let errorMessage, videos.isEmpty {
                    ContentUnavailableView {
                        Label("Ca't load catalogue", systemImage: "wifi.slash")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") {
                            Task { await load() }
                        }
                    }
                }
            }
            .navigationTitle("StreamLab")
            .refreshable {
                await load()
            }
            .task {
                await load()
            }
        }
    }
    
    private func load() async {
        isLoading = true
        
        defer { isLoading = false}
             
        do {
            videos = try await service.fetchCatalog()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
