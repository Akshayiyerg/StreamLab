//
//  Video.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-13.
//


import Foundation

struct Video: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let synopsis: String
    let category: String
    let durationMinutes: Int
    let isPremium: Bool
    let streamURL: URL
}
