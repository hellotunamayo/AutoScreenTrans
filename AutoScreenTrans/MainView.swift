//
//  ContentView.swift
//  AutoScreenTrans
//
//  Created by Minyoung Yoo on 9/24/26.
//

import SwiftUI
import NaturalLanguage

enum InferenceType {
    case macOS
    case LLMModel
}

struct MainView: View {
    @State private var selectedWindow: CGWindowID = 0
    @State private var windowInfoList: [WindowInfo] = []
    @State private var capturedWindowImage: NSImage = .init()
    @State private var sourceLanguage: Locale = Locale(components: .init(languageCode: .japanese))
    @State private var targetLanguage: Locale = Locale(components: .init(languageCode: .korean))
    @State private var capturedText: String = ""
    @State private var translatedText: String = ""
    @State private var modelTranslatedText: String = ""
    @State private var statusMessage: String = ""
    
    @StateObject var translator: MLXTranslator = .shared
    let translationController: TranslationController = .init()
    
    let windowListController: WindowCaptureController = .init()
    let visionController: VisionController = .init()
    let inferenceType: InferenceType = .LLMModel
    
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
            
            switch inferenceType {
                case .macOS:
                    ScrollView {
                        Text(translatedText)
                            .font(Font.title)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                    }
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                    
                case .LLMModel:
                    ScrollView {
                        Text(modelTranslatedText)
                            .font(Font.title)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                    }
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
            }
            
            VStack {
                Text(statusMessage).font(Font.caption)
                
                Picker(selection: $selectedWindow, label: Text("Window List")) {
                    Text("Select Window").tag(CGWindowID(0))
                    ForEach(windowInfoList) { window in
                        Text("\(window.appName): \(window.title)")
                            .tag(window.windowID)
                    }
                }
                
                Picker(selection: $sourceLanguage, label: Text("Source Language")) {
                    Text("Select Language").tag("")
                    Text("日本語").tag(Locale(components: .init(languageCode: .japanese)))
                    Text("English").tag(Locale(components: .init(languageCode: .english)))
                    Text("한국어").tag(Locale(components: .init(languageCode: .korean)))
                }
                
                Picker(selection: $targetLanguage, label: Text("Target Language")) {
                    Text("Select Language").tag("")
                    Text("한국어").tag(Locale(components: .init(languageCode: .korean)))
                    Text("English").tag(Locale(components: .init(languageCode: .english)))
                    Text("日本語").tag(Locale(components: .init(languageCode: .japanese)))
                }
                
                Divider()
                    .padding(.vertical, 20)
                
                Button {
                    Task {
                        
                        let capturedImage = try await windowListController.captureWindow(windowID: selectedWindow)
                        let results = try await visionController.performOCR(on: capturedImage, languages: [sourceLanguage])
                        capturedText = ""
                        for result in results {
                            capturedText.append(result.text)
                        }
                        
                        print("Captured Text: \(capturedText)")
                        
                        targetLanguage = Locale(components: .init(languageCode: .korean))
                        translatedText = try await translationController.translateText(text: capturedText,
                                                            from: sourceLanguage,
                                                            to: targetLanguage)
                        
                        do {
                            statusMessage = "Preparing model..."
                            await translator.prepareModel()
                            
                            statusMessage = "Starting inference..."
                            modelTranslatedText = try await translator.translate(
                                sourceLanguage: sourceLanguage.localizedString(forLanguageCode: sourceLanguage.identifier) ?? "English",
                                targetLanguage: targetLanguage.localizedString(forLanguageCode: targetLanguage.identifier) ?? "Korean",
                                givenText: capturedText,
                                glossary: [:]
                            )
                            
                            statusMessage = "Job finished."
                        } catch {
                            statusMessage = error.localizedDescription
                            print("Error: \(error)")
                        }
                        
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
        .onReceive(translator.$modelStatus) { message in
            statusMessage = message
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
