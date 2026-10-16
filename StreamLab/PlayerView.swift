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
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
                
                Spacer()
            }
            .padding(.horizontal)
            
            if let player {
                VideoPlayer(player: player)
            } else {
                Spacer()
            }
        }
        .background(Color.black.ignoresSafeArea())
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
