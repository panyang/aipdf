// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 AIPDF contributors
import SwiftUI
import AppKit

@main struct AIPDFApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(model)
                .frame(minWidth: 1080, minHeight: 720)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    if model.selected == nil, let tool=model.tools.first { model.select(tool) }
                    model.addFiles([url])
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1360,height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加文件…") { model.chooseFiles() }.keyboardShortcut("o").disabled(model.selected == nil || model.busy)
            }
            CommandGroup(replacing: .appSettings) {
                Button("设置…") { model.showSettings = true }.keyboardShortcut(",")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Deterministic capture of this application's own content for visual QA.
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > index+1 {
            let path = CommandLine.arguments[index+1]
            DispatchQueue.main.asyncAfter(deadline: .now()+3) {
                guard let window = NSApp.windows.first, let view = window.contentView,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                NSApp.terminate(nil)
            }
        }
    }
}
