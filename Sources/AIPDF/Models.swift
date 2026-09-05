// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 AIPDF contributors
import AppKit
import SwiftUI
import PDFKit

struct ToolField: Codable, Identifiable {
    var id: String { key }
    let key: String
    let label: String
    let value: String
    let kind: String
    let choices: [String]
    let help: String
}

struct PDFTool: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let category: String
    let icon: String
    let fields: [ToolField]
    let extensions: [String]
    let multiple: Bool
    let note: String
    let dependency: String
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    var color: Color {
        switch category {
        case "整理页面": return Color(hex: "D86D52")
        case "优化文件": return Color(hex: "439680")
        case "格式转换": return Color(hex: "5482B7")
        case "编辑内容": return Color(hex: "B58642")
        case "安全保护": return Color(hex: "8A70AC")
        default: return Color(hex: "5B7E79")
        }
    }
}

struct JobRecord: Codable, Identifiable {
    let id: UUID
    let tool: String
    let date: Date
    let outputs: [String]
    let directory: String
    let count: Int
    let elapsed: Double
}

struct WorkflowStep: Codable, Identifiable {
    var id = UUID()
    var toolID: String
    var options: [String: String]
}

struct WorkflowPreset: Codable, Identifiable {
    var id = UUID()
    var name: String
    var steps: [WorkflowStep]
}

struct FormValue: Identifiable {
    var id: String { name }
    var name: String
    var value: String
    var kind: String
    var choices: [String]
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 255)/255, green: Double((value >> 8) & 255)/255, blue: Double(value & 255)/255, opacity: 1)
    }
    static let ink = Color(hex: "27333D")
    static let muted = Color(hex: "7F878A")
    static let canvas = Color(hex: "F7F8FA")
    static let coral = Color(hex: "D7664D")
}

enum AppPaths {
    static var userSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AIPDF", isDirectory: true)
    }
    static var isInstalled: Bool { Bundle.main.object(forInfoDictionaryKey: "AIPDFRuntimeID") != nil }
    static var project: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "AIPDFProjectPath") as? String { return URL(fileURLWithPath: value) }
        if isInstalled { return userSupport }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
    static var backend: URL {
        if let resources = Bundle.main.resourceURL, FileManager.default.fileExists(atPath: resources.appendingPathComponent("backend/engine.py").path) {
            return resources.appendingPathComponent("backend")
        }
        return project.appendingPathComponent("backend")
    }
    static var python: URL {
        if isInstalled {
            let id = Bundle.main.object(forInfoDictionaryKey: "AIPDFRuntimeID") as? String ?? ""
            let safe = id.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", options: .regularExpression) != nil
            return userSupport.appendingPathComponent("Runtimes").appendingPathComponent(safe ? id : "unavailable").appendingPathComponent("bin/python")
        }
        return project.appendingPathComponent(".venv/bin/python")
    }
    static var support: URL {
        if CommandLine.arguments.contains("--snapshot") || CommandLine.arguments.contains("--test-result") {
            let temp=project.appendingPathComponent("tmp/app-state",isDirectory:true)
            try? FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)
            return temp
        }
        let root = userSupport
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return root
    }
}

/// Each request uses a dedicated worker. Documents and passwords travel via stdin,
/// never command-line arguments, logs, preferences or network services.
final class Worker: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        let p = process
        lock.unlock()
        if p?.isRunning == true { p?.terminate() }
    }

    func call(_ request: [String: Any], progress: @escaping (String, Double) -> Void = { _, _ in }) throws -> [String: Any] {
        guard FileManager.default.isExecutableFile(atPath: AppPaths.python.path) else {
            throw NSError(domain: "AIPDF", code: 3, userInfo: [NSLocalizedDescriptionKey: "本地运行环境缺失。请重新下载源码并双击 Install.command 修复安装。"])
        }
        let p = Process()
        p.executableURL = AppPaths.python
        p.arguments = [AppPaths.backend.appendingPathComponent("engine.py").path]
        p.currentDirectoryURL = AppPaths.backend
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        environment["PYTHONUNBUFFERED"] = "1"
        if let r = Bundle.main.resourceURL { environment["AIPDF_VISION"] = r.appendingPathComponent("VisionHelper").path }
        p.environment = environment
        let input = Pipe(), output = Pipe(), errors = Pipe()
        p.standardInput = input; p.standardOutput = output; p.standardError = errors
        let bufferLock = NSLock()
        var buffer = Data()
        errors.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            bufferLock.lock()
            buffer.append(data)
            while let newline = buffer.firstIndex(of: 10) {
                let line = buffer.prefix(upTo: newline)
                buffer.removeSubrange(...newline)
                if let item = try? JSONSerialization.jsonObject(with: line) as? [String: Any], let message = item["message"] as? String {
                    progress(message, item["progress"] as? Double ?? 0)
                }
            }
            bufferLock.unlock()
        }
        defer {
            errors.fileHandleForReading.readabilityHandler = nil
            lock.lock(); process = nil; lock.unlock()
        }
        lock.lock()
        if cancelled { lock.unlock(); throw NSError(domain: "AIPDF", code: 1, userInfo: [NSLocalizedDescriptionKey: "处理已取消。"] ) }
        process = p
        do { try p.run() } catch { lock.unlock(); throw error }
        lock.unlock()
        let payload = try JSONSerialization.data(withJSONObject: request)
        try input.fileHandleForWriting.write(contentsOf: payload)
        try input.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "AIPDF", code: 2, userInfo: [NSLocalizedDescriptionKey: cancelled ? "处理已取消。" : "处理引擎未返回有效结果，请检查本地环境。"])
        }
        return result
    }
}

@MainActor final class AppModel: ObservableObject {
    @Published var tools: [PDFTool] = []
    @Published var category = "全部工具"
    @Published var search = ""
    @Published var selected: PDFTool?
    @Published var files: [URL] = []
    @Published var previewURL: URL?
    @Published var previewPage = 0
    @Published var options: [String: String] = [:]
    @Published var password = ""
    @Published var busy = false
    @Published var message = ""
    @Published var fraction = 0.0
    @Published var error: String?
    @Published var outputs: [URL] = []
    @Published var outputDirectory: URL
    @Published var lastOutputDirectory: URL?
    @Published var history: [JobRecord] = []
    @Published var health: [String: Bool] = [:]
    @Published var showSettings = false
    @Published var showHistory = false
    @Published var formValues: [FormValue] = []
    @Published var steps: [WorkflowStep] = []
    @Published var presets: [WorkflowPreset] = []
    @Published var presetName = "我的常用流程"
    @Published var strokes: [[CGPoint]] = []
    @Published var pageOrder: [Int] = []
    @Published var pageCount = 0
    private var worker: Worker?
    let categories = ["全部工具", "整理页面", "优化文件", "格式转换", "编辑内容", "安全保护", "工作流程"]

    init() {
        let saved = UserDefaults.standard.string(forKey: "outputDirectory")
        outputDirectory = saved.map { URL(fileURLWithPath: $0) } ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        if let data = try? Data(contentsOf: AppPaths.backend.appendingPathComponent("catalog.json")), let decoded = try? JSONDecoder().decode([PDFTool].self, from: data) { tools = decoded }
        if let data = try? Data(contentsOf: AppPaths.support.appendingPathComponent("history.json")) { history = (try? JSONDecoder().decode([JobRecord].self, from: data)) ?? [] }
        if let data = try? Data(contentsOf: AppPaths.support.appendingPathComponent("workflows.json")) { presets = (try? JSONDecoder().decode([WorkflowPreset].self, from: data)) ?? [] }
        refreshHealth()
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--tool"), args.count > i+1, let tool = tools.first(where: { $0.id == args[i+1] }) {
            select(tool)
            if let j = args.firstIndex(of: "--input"), args.count > j+1 { addFiles([URL(fileURLWithPath: args[j+1])]) }
            if let j = args.firstIndex(of: "--output"), args.count > j+1 { outputDirectory=URL(fileURLWithPath:args[j+1]) }
            if args.contains("--test-result") { Task { self.run() } }
        }
    }

    var filteredTools: [PDFTool] {
        tools.filter { (category == "全部工具" || $0.category == category) && (search.isEmpty || ($0.name+$0.subtitle+$0.id).localizedCaseInsensitiveContains(search)) }
    }
    var canRun: Bool { !files.isEmpty || (selected?.id == "html_to_pdf" && !(options["url"] ?? "").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) }

    func select(_ tool: PDFTool) {
        guard !busy else { return }
        selected = tool; showHistory = false
        options = Dictionary(uniqueKeysWithValues: tool.fields.map { ($0.key, $0.value) })
        outputs = []; error = nil; strokes = []; steps = []; formValues = []; password = ""
        files = files.filter { tool.extensions.contains($0.pathExtension.lowercased()) }
        if !tool.multiple { files = Array(files.prefix(1)) }
        if let first = files.first { loadPreview(first) } else { previewURL = nil; pageCount = 0 }
    }

    func addFiles(_ urls: [URL]) {
        guard let tool = selected, !busy else { return }
        let accepted = urls.filter { tool.extensions.contains($0.pathExtension.lowercased()) }
        if accepted.count != urls.count { error = "部分文件格式不适用于此工具。支持：" + tool.extensions.joined(separator: "、") }
        if tool.multiple { for url in accepted where !files.contains(url) { files.append(url) } }
        else if let first = accepted.first { files = [first] }
        outputs = []
        if let first = files.first { loadPreview(first) }
    }

    func chooseFiles() {
        guard let tool = selected else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = tool.multiple
        panel.canChooseDirectories = false
        panel.title = "选择需要处理的文件"
        panel.allowedContentTypes = tool.extensions.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK { addFiles(panel.urls) }
    }

    func loadPreview(_ url: URL) {
        previewURL = url; previewPage = 0
        if let doc = PDFDocument(url: url) {
            if doc.isLocked { _ = doc.unlock(withPassword: password) }
            pageCount = doc.isLocked ? 0 : doc.pageCount
            pageOrder = Array(1...max(1, pageCount))
        } else { pageCount = 0; pageOrder = [] }
        if selected?.id == "forms" { inspectForm() }
    }

    func chooseOutput() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true; panel.prompt = "选择输出文件夹"
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url; UserDefaults.standard.set(url.path, forKey: "outputDirectory")
        }
    }

    func refreshHealth() {
        Task {
            let response = await Task.detached { try? Worker().call(["operation": "health"]) }.value
            guard let response else { health = [:]; return }
            health = ["office": response["office"] as? Bool ?? false, "vision": response["vision"] as? Bool ?? false, "core": true]
        }
    }

    func inspectForm() {
        guard let url = files.first else { return }
        let request: [String: Any] = ["operation": "inspect", "files": [url.path], "options": ["password": password]]
        Task {
            let response = await Task.detached { try? Worker().call(request) }.value
            guard files.first == url else { return }
            if let err = response?["error"] as? String { error = err; return }
            var seen = Set<String>()
            formValues = (response?["fields"] as? [[String: Any]] ?? []).compactMap { f in
                let name = f["name"] as? String ?? ""
                guard seen.insert(name).inserted else { return nil }
                return FormValue(name: name, value: f["value"] as? String ?? "", kind: f["type"] as? String ?? "Text", choices: f["choices"] as? [String] ?? [])
            }
        }
    }

    func selectRegion(page: Int, rect: CGRect) {
        options["x"] = String(format: "%.1f", rect.minX)
        options["y"] = String(format: "%.1f", rect.minY)
        options["width"] = String(format: "%.1f", rect.width)
        options["height"] = String(format: "%.1f", rect.height)
        options["pages"] = String(page+1)
    }

    func run() {
        guard let tool = selected, !busy, canRun else { return }
        var payload: [String: Any] = options
        payload["password"] = password
        payload["formValues"] = Dictionary(uniqueKeysWithValues: formValues.map { ($0.name, $0.value) })
        payload["strokes"] = strokes.map { line in line.map { [Double($0.x), Double($0.y)] } }
        payload["steps"] = steps.map { ["operation": $0.toolID, "options": $0.options] as [String: Any] }
        let request: [String: Any] = ["operation": tool.id, "files": files.map(\.path), "options": payload, "outputDir": outputDirectory.path]
        busy = true; outputs = []; error = nil; fraction = 0; message = "正在准备本地处理…"
        let active = Worker(); worker = active
        let inputCount = files.count
        Task {
            let response: [String: Any]
            do {
                response = try await Task.detached {
                    try active.call(request) { text, value in
                        Task { @MainActor [weak self] in self?.message = text; self?.fraction = value }
                    }
                }.value
            } catch { response = ["ok": false, "error": error.localizedDescription] }
            busy = false; worker = nil
            if response["ok"] as? Bool == true {
                outputs = (response["outputs"] as? [String] ?? []).map { URL(fileURLWithPath: $0) }
                lastOutputDirectory = (response["outputDir"] as? String).map { URL(fileURLWithPath: $0) }
                message = "处理完成"; fraction = 1
                let record = JobRecord(id: UUID(), tool: tool.name, date: Date(), outputs: outputs.map(\.path), directory: lastOutputDirectory?.path ?? "", count: inputCount, elapsed: response["elapsed"] as? Double ?? 0)
                history.insert(record, at: 0); history = Array(history.prefix(100))
                persistHistory()
                if let preview = outputs.first(where: { $0.pathExtension == "pdf" }) { previewURL = preview }
            } else { error = response["error"] as? String ?? "处理失败，请检查文件。"; message = "未完成" }
            if let i=CommandLine.arguments.firstIndex(of:"--test-result"),CommandLine.arguments.count>i+1 {
                let symbols=tools.filter { NSImage(systemSymbolName:$0.icon,accessibilityDescription:nil)==nil }.map(\.id)
                let report:[String:Any] = ["ok":error==nil,"outputs":outputs.map(\.path),"error":error ?? "","missingIcons":symbols]
                if let data=try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted) { try? data.write(to:URL(fileURLWithPath:CommandLine.arguments[i+1])) }
                NSApp.terminate(nil)
            }
        }
    }

    func cancel() { worker?.cancel(); message = "正在取消…" }
    func persistHistory() {
        if let data = try? JSONEncoder().encode(history) { try? data.write(to: AppPaths.support.appendingPathComponent("history.json"), options: .atomic) }
    }
    func savePreset() {
        guard !steps.isEmpty else { return }
        // Never save document passwords in reusable workflows.
        let safe = steps.map { step -> WorkflowStep in
            var copy = step; copy.options.removeValue(forKey: "password"); copy.options.removeValue(forKey: "newPassword"); return copy
        }
        presets.append(WorkflowPreset(name: presetName.isEmpty ? "常用流程" : presetName, steps: safe))
        if let data = try? JSONEncoder().encode(presets) { try? data.write(to: AppPaths.support.appendingPathComponent("workflows.json"), options: .atomic) }
    }
    func useResults() {
        guard let tool = selected else { return }
        files = outputs.filter { tool.extensions.contains($0.pathExtension.lowercased()) }
        if let first = files.first { loadPreview(first) }
        outputs = []
    }
}

import UniformTypeIdentifiers
