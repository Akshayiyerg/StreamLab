//
//  CachedVideo.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-14.
//

import Foundation
import SwiftData

@Model
final class CachedVideo {
    @Attribute(.unique) var id: String
    var title: String
    var synopsis: String
    var category: String
    var durationMinutes: Int
    var isPremium: Bool
    var streamURL: URL
    var sortIndex: Int
    
    init(video: Video, sortIndex: Int) {
        self.id = video.id
        self.title = video.title
        self.synopsis = video.synopsis
        self.category = video.category
        self.durationMinutes = video.durationMinutes
        self.isPremium = video.isPremium
        self.streamURL = video.streamURL
        self.sortIndex = sortIndex
    }
    
    func update(from video: Video, sortIndex: Int) {
        title = video.title
        synopsis = video.synopsis
        category = video.category
        durationMinutes = video.durationMinutes
        isPremium = video.isPremium
        streamURL = video.streamURL
        self.sortIndex = sortIndex
    }
}
