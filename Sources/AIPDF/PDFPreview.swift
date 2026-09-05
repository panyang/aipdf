// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 AIPDF contributors
import SwiftUI
import PDFKit

final class SelectingPDFView: PDFView {
    var selectsRegion = false
    var onRegion: ((Int, CGRect) -> Void)?
    private var anchor: CGPoint?
    private var regionPage: PDFPage?
    private var shape = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        shape.fillColor = NSColor.systemOrange.withAlphaComponent(0.14).cgColor
        shape.strokeColor = NSColor.systemOrange.cgColor
        shape.lineWidth = 1.5
        shape.lineDashPattern = [5, 3]
        layer?.addSublayer(shape)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func mouseDown(with event: NSEvent) {
        guard selectsRegion else { super.mouseDown(with: event); return }
        let point = convert(event.locationInWindow, from: nil)
        guard let page = page(for: point, nearest: false) else { return }
        anchor = point; regionPage = page; shape.path = nil
    }
    override func mouseDragged(with event: NSEvent) {
        guard selectsRegion, let start = anchor else { super.mouseDragged(with: event); return }
        let current = convert(event.locationInWindow, from: nil)
        let box = CGRect(x: min(start.x,current.x), y: min(start.y,current.y), width: abs(start.x-current.x), height: abs(start.y-current.y))
        shape.path = CGPath(rect: box, transform: nil)
    }
    override func mouseUp(with event: NSEvent) {
        guard selectsRegion, let start = anchor, let page = regionPage else { super.mouseUp(with: event); return }
        defer { anchor = nil; regionPage = nil }
        let end = convert(event.locationInWindow, from: nil)
        let a = convert(start, to: page), b = convert(end, to: page)
        let native = CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(a.x-b.x), height: abs(a.y-b.y)).intersection(page.bounds(for: .cropBox))
        guard native.width > 3, native.height > 3, let doc = document else { return }
        // Use the page's actual display rectangle to account for crop origins and rotation.
        let shown = convert(page.bounds(for: .cropBox), from: page)
        let chosen = convert(native, from: page)
        let rotated = page.rotation % 180 != 0
        let original = page.bounds(for: .cropBox)
        let displayWidth = rotated ? original.height : original.width
        let displayHeight = rotated ? original.width : original.height
        let x = (chosen.minX-shown.minX)/shown.width*displayWidth
        let y = (shown.maxY-chosen.maxY)/shown.height*displayHeight
        let rect = CGRect(x: max(0,x), y: max(0,y), width: chosen.width/shown.width*displayWidth, height: chosen.height/shown.height*displayHeight)
        onRegion?(doc.index(for: page),rect)
    }
    func clearSelectionBox() { shape.path = nil }
}

struct PDFPreview: NSViewRepresentable {
    var url: URL
    var password: String
    var page: Int
    var selection: Bool
    var onRegion: (Int, CGRect) -> Void

    final class Coordinator { var url: URL?; var page = -1; var password = "" }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> SelectingPDFView {
        let view = SelectingPDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = NSColor(Color(hex: "EDEFF2"))
        view.displaysPageBreaks = true
        return view
    }
    func updateNSView(_ view: SelectingPDFView, context: Context) {
        view.selectsRegion = selection
        view.onRegion = onRegion
        if context.coordinator.url != url || context.coordinator.password != password {
            context.coordinator.url = url; context.coordinator.password = password
            let document = PDFDocument(url: url)
            if document?.isLocked == true { _ = document?.unlock(withPassword: password) }
            view.document = document
            view.clearSelectionBox()
            context.coordinator.page = -1
        }
        if context.coordinator.page != page {
            if let target = view.document?.page(at: page) { view.go(to: target) }
            context.coordinator.page = page
            view.clearSelectionBox()
        }
    }
}

struct SignaturePad: View {
    @Binding var strokes: [[CGPoint]]
    @State private var current: [CGPoint] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("手写签名").font(.system(size: 12, weight: .medium))
                Spacer()
                Button("清除") { strokes = []; current = [] }.buttonStyle(.plain).foregroundStyle(Color.coral)
            }
            GeometryReader { geometry in
                Canvas { context, size in
                    for stroke in strokes + [current] where stroke.count > 1 {
                        var path = Path()
                        path.move(to: CGPoint(x: stroke[0].x*size.width, y: stroke[0].y*size.height))
                        for p in stroke.dropFirst() { path.addLine(to: CGPoint(x: p.x*size.width, y: p.y*size.height)) }
                        context.stroke(path, with: .color(.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                }
                .background(.white)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    current.append(CGPoint(x: min(1,max(0,value.location.x/geometry.size.width)), y: min(1,max(0,value.location.y/geometry.size.height))))
                }.onEnded { _ in if current.count > 1 { strokes.append(current) }; current=[] })
                .overlay(alignment: .bottom) { Rectangle().fill(Color.gray.opacity(0.18)).frame(height: 1).padding(.horizontal, 18).padding(.bottom, 30).allowsHitTesting(false) }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }.frame(height: 125)
            Text("使用触控板或鼠标书写").font(.system(size: 10)).foregroundStyle(Color.muted)
        }
    }
}

struct PageThumbnail: View {
    let url: URL
    let page: Int
    let password: String
    @State private var image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFit() }
            else { Rectangle().fill(.white).overlay(ProgressView().controlSize(.mini)) }
        }
        .frame(width: 72,height: 94)
        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        .task(id: "\(url.path)-\(page)-\(password)") {
            if let doc = PDFDocument(url: url) {
                if doc.isLocked { _ = doc.unlock(withPassword: password) }
                image = doc.page(at: page-1)?.thumbnail(of: NSSize(width: 144,height: 188), for: .cropBox)
            }
        }
    }
}
