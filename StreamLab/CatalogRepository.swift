//
//  CatalogRepository.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-14.
//

import Foundation
import SwiftData

@MainActor
struct CatalogRepository {
    private let service = CatalogService()
    
    func refresh(into context: ModelContext) async throws {
        let videos = try await service.fetchCatalog()
        
        let existing = try context.fetch(FetchDescriptor<CachedVideo>())
        var cachedByID = Dictionary(uniqueKeysWithValues: existing.map { ( $0.id, $0 ) })
        for (index, video) in videos.enumerated() {
            if let cached = cachedByID.removeValue(forKey: video.id) {
                cached.update(from: video, sortIndex: index)
            } else {
                context.insert(CachedVideo(video: video, sortIndex: index))
            }
        }
        
        for stale in cachedByID.values {
            context.delete(stale)
        }
        
        try context.save()
    }
}
