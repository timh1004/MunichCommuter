//
//  MunichCommuterWatchApp.swift
//  MunichCommuterWatch WatchKit Extension
//
//  Created by AI Assistant
//

import SwiftUI

@main
struct MunichCommuterWatchApp: App {
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("🚀 Munich Commuter Watch App started")
                }
        }
    }
}