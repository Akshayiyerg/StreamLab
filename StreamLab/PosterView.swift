//
//  PosterView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-16.
//

import SwiftUI

struct PosterView: View {
    let category: String
    
    private var style: (colors: [Color], symbol: String) {
        switch category {
        case "Animation": ([.orange, .pink], "sparkles")
        case "Sci-Fi": ([.indigo, .purple], "atom")
        case "Tech Demos": ([.teal, .blue], "waveform")
        default: ([.gray, .black], "film")
        }
    }
    
    var body: some View {
        LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: style.symbol)
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.85))
            }
    }
}
