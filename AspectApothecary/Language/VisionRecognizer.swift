import CoreGraphics
import CoreML
import Foundation
import Vision

struct VisionRecognizer {
    func classify(
        _ image: CGImage,
        maxLabels: Int = 6,
        minConfidence: Float = 0.08
    ) async throws -> [String] {
        #if targetEnvironment(simulator)
        let request = VNClassifyImageRequest()
        if let cpuDevice = MLComputeDevice.allComputeDevices.first(where: { "\($0)".contains("CPU") }),
           let stages = try? request.supportedComputeStageDevices {
            for stage in stages.keys {
                request.setComputeDevice(cpuDevice, for: stage)
            }
        }
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let observations = (request.results ?? [])
        return observations
            .filter { $0.confidence >= minConfidence }
            .prefix(maxLabels)
            .map(\.identifier)
        #else
        let request = ClassifyImageRequest()
        let observations = try await request.perform(on: image)
        return observations
            .filter { $0.confidence >= minConfidence }
            .prefix(maxLabels)
            .map(\.identifier)
        #endif
    }
}
