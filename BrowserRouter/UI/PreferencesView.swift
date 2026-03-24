//
//  PreferencesView.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store: AppStateStore

    var body: some View {
        TabView {
            GeneralSettingsView(store: store)
                .tabItem { Label("General", systemImage: "gear") }
            BrowsersSettingsView(store: store)
                .tabItem { Label("Browsers", systemImage: "globe") }
            RulesListView(store: store)
                .tabItem { Label("Rules", systemImage: "list.bullet") }
        }
        .frame(minWidth: UIConstants.preferencesMinSize.width,
               idealWidth: UIConstants.preferencesSize.width,
               minHeight: UIConstants.preferencesMinSize.height,
               idealHeight: UIConstants.preferencesSize.height)
    }
}
