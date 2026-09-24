//
//  WindowListController.swift
//  AutoScreenTrans
//
//  Created by Minyoung Yoo on 9/24/26.
//

import Foundation
import ScreenCaptureKit
import AppKit

struct WindowInfo: Identifiable, Hashable {
    let id: UUID = UUID()
    let appName: String
    let title: String
    let windowID: CGWindowID
}

enum WindowCaptureError: Error {
    case windowNotFound
    case captureFailed
}

final class WindowCaptureController: Sendable {
    func fetchWindowList() async throws -> [WindowInfo] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            var result: [WindowInfo] = []
            
            for window in content.windows {
                let appName = window.owningApplication?.applicationName ?? "Unknown App"
                let title = window.title ?? "No Title"
                let windowID = window.windowID
                let windowInfo = WindowInfo(appName: appName, title: title, windowID: windowID)
                
                result.append(windowInfo)
            }
            
            return result
        } catch {
            print("Error: \(error)")
            throw error
        }
    }
    
    func captureWindow(windowID: CGWindowID) async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        
        guard let targetWindow = content.windows.first(where: { $0.windowID == windowID }) else {
            throw WindowCaptureError.windowNotFound
        }
        
        let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
        let config = SCStreamConfiguration()
        
        let scale = Int(NSScreen.main?.backingScaleFactor ?? 2.0)
        config.width = Int(targetWindow.frame.width) * scale
        config.height = Int(targetWindow.frame.height) * scale
        config.showsCursor = false
        
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: targetWindow.frame.width, height: targetWindow.frame.height))
        
        guard let trimmedImage = nsImage.trimmingTitleBar() else {
            return nsImage
        }
        
        return trimmedImage
    }
}

extension NSImage {
    func trimmingTitleBar(height titleBarHeight: CGFloat = 28.0) -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let scale = CGFloat(cgImage.width) / self.size.width
        let cropPixelHeight = titleBarHeight * scale
        
        
        let targetRect = CGRect(
            x: 0,
            y: cropPixelHeight,
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height) - cropPixelHeight
        )
        
        guard targetRect.height > 0, let croppedCGImage = cgImage.cropping(to: targetRect) else {
            return nil
        }
        
        let newSize = NSSize(
            width: self.size.width,
            height: self.size.height - titleBarHeight
        )
        
        return NSImage(cgImage: croppedCGImage, size: newSize)
    }
}
