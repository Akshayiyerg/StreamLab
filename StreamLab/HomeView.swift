//
//  HomeView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-08.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CachedVideo.sortIndex) private var videos: [CachedVideo]
    
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let repository = CatalogRepository()
    
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
                        Label("Can't load catalogue", systemImage: "wifi.slash")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") {
                            Task { await load() }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                if errorMessage != nil && !videos.isEmpty {
                    Label("Offline · showing saved catalogue", systemImage: "wifi.slash")
                        .font(.footnote)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(.yellow.opacity(0.3))
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
            try await repository.refresh(into: modelContext)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
