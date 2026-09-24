//
//  ContentView.swift
//  AutoScreenTrans
//
//  Created by Minyoung Yoo on 9/24/26.
//

import SwiftUI
import NaturalLanguage

struct MainView: View {
    @State private var selectedWindow: CGWindowID = 0
    @State private var windowInfoList: [WindowInfo] = []
    @State private var capturedWindowImage: NSImage = .init()
    @State private var selectedLanguage: String = "en-US"
    @State private var capturedText: String = ""
    @State private var translatedText: String = ""
    
    let windowListController: WindowCaptureController = .init()
    let visionController: VisionController = .init()
    let translationController: TranslationController = .init()
    
    var body: some View {
        VStack {
            
            ScrollView {
                Text(capturedText)
                    .font(Font.title)
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
            .padding(.bottom, 10)
            
            ScrollView {
                Text(translatedText)
                    .font(Font.title)
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
            
            VStack {
                Picker(selection: $selectedWindow, label: Text("Window List")) {
                    Text("Select Window").tag(CGWindowID(0))
                    ForEach(windowInfoList) { window in
                        Text("\(window.appName): \(window.title)")
                            .tag(window.windowID)
                    }
                }
                
                Picker(selection: $selectedLanguage, label: Text("Target Language")) {
                    Text("Select Language").tag("")
                    Text("English").tag("en-US")
                    Text("한국어").tag("ko-KR")
                    Text("日本語").tag("ja-JP")
                }
                
                Divider()
                    .padding(.vertical, 20)
                
                Button {
                    Task {
                        
                        let capturedImage = try await windowListController.captureWindow(windowID: selectedWindow)
                        let results = try await visionController.performOCR(on: capturedImage, languages: [selectedLanguage])
                        capturedText = ""
                        for result in results {
                            capturedText.append(result.text)
                        }
                        
                        let fromLanguageIdentifier = getLanguageCode(from: selectedLanguage)
                        
                        translatedText = try await translationController.translateText(text: capturedText, from: Locale.Language(identifier: fromLanguageIdentifier))
                        
                    }
                } label: {
                    Text("Get text & translate from window")
                }
                .buttonStyle(BorderedProminentButtonStyle())
                
                Button {
                    Task {
                        try await self.refreshWindowList()
                    }
                } label: {
                    Text("Refresh window list")
                        .underline(true)
                }
                .buttonStyle(.borderless)
            }
            .padding()

        }
        .onAppear {
            Task {
                try await self.refreshWindowList()
            }
        }
        .padding()
        
    }
    
    private func refreshWindowList() async throws {
        let windowList = try await windowListController.fetchWindowList()
        windowInfoList = windowList
    }
    
    private func getLanguageCode(from languageTag: String) -> String {
        let language = Locale.Language(components: .init(identifier: languageTag))
        return language.languageCode?.identifier ?? languageTag
    }
}

#Preview {
    MainView()
}
