//
//  PermissionController.swift
//  AutoScreenTrans
//
//  Created by Minyoung Yoo on 9/25/26.
//

import ScreenCaptureKit
import AppKit

class PermissionController {
    func checkAndRequestScreenCapturePermission() {
        
        if CGPreflightScreenCaptureAccess() {
            print("화면 기록 권한이 승인되어 있습니다.")
        } else {
            
            print("화면 기록 권한이 필요합니다.")
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            NSWorkspace.shared.open(url)
        }
    }
}
