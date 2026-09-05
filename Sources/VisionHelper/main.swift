import Foundation
import Vision
import AppKit
import CoreImage

func fail(_ text: String) -> Never {
    FileHandle.standardError.write(Data(text.utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 3 else { fail("Missing input") }
let source = URL(fileURLWithPath: args[2])
guard let image = NSImage(contentsOf: source), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fail("Cannot decode image") }

do {
    if args[1] == "ocr" {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
        let boxes: [[String: Any]] = (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let r = observation.boundingBox
            return ["text": candidate.string, "x": r.minX, "y": 1-r.maxY, "w": r.width, "h": r.height]
        }
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: boxes))
    } else {
        guard args.count >= 4 else { fail("Missing output") }
        var ci = CIImage(cgImage: cg)
        if args[1] == "scan" {
            let request = VNDetectRectanglesRequest()
            request.maximumObservations = 1
            request.minimumConfidence = 0.7
            request.minimumSize = 0.35
            request.minimumAspectRatio = 0.25
            try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
            if let rectangle = request.results?.first {
                func vector(_ p: CGPoint) -> CIVector { CIVector(x: p.x * ci.extent.width, y: p.y * ci.extent.height) }
                ci = ci.applyingFilter("CIPerspectiveCorrection", parameters: [
                    "inputTopLeft": vector(rectangle.topLeft), "inputTopRight": vector(rectangle.topRight),
                    "inputBottomLeft": vector(rectangle.bottomLeft), "inputBottomRight": vector(rectangle.bottomRight)
                ])
            }
        }
        let context = CIContext()
        guard let result = context.createCGImage(ci, from: ci.extent) else { fail("Cannot render image") }
        let bitmap = NSBitmapImageRep(cgImage: result)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { fail("Cannot encode image") }
        try data.write(to: URL(fileURLWithPath: args[3]), options: .atomic)
    }
} catch {
    fail("Vision processing failed")
}
