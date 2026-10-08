//
//  RootView.swift
//  StreamLab
//
//  Created by Akshay Ganesh on 2026-10-08.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "play.rectangle.fill") {
                HomeView()
            }
            Tab("Account", systemImage: "person.crop.circle") {
                AccountView()
            }
        }
    }
}

#Preview {
    RootView()
}
