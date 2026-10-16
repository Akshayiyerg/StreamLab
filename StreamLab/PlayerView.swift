//
//  PlayerView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-16.
//

import SwiftUI
import AVKit

struct PlayerView: View {
    let url: URL
    let isPremium: Bool
    
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
            .padding()
            .accessibilityLabel("Close")
        }
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: store.isSubscribed) {
            if !store.canWatch(isPremium: isPremium) {
                player?.pause()
                dismiss()
            }
        }
    }
}
