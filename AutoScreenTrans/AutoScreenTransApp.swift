//
//  AutoScreenTransApp.swift
//  AutoScreenTrans
//
//  Created by Minyoung Yoo on 9/24/26.
//

import SwiftUI

@main
struct AutoScreenTransApp: App {
    let permissionController: PermissionController = .init()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    permissionController.checkAndRequestScreenCapturePermission()
                }
        }
    }
}
