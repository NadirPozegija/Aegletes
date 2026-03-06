//
// Histogram.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/6/26.
// Rev: 2

import Foundation
import CoreImage
import SwiftUI

// MARK: - Histogram Processor

final class HistogramProcessor {

    private let ciContext: CIContext
    private let binCount: Int
    private let minUpdateInterval: CFTimeInterval

    private var lastUpdate: CFTimeInterval = 0

    /// - Parameters:
    ///   - ciContext: Optional shared CIContext; if nil, a new one is created.
    ///   - binCount: Number of histogram bins (e.g. 64).
    ///   - minUpdateInterval: Minimum time between updates in seconds (e.g. 0.1 for 10 Hz).
    init(ciContext: CIContext? = nil,
         binCount: Int = 64,
         minUpdateInterval: CFTimeInterval = 0.1) {
        self.ciContext = ciContext ?? CIContext(options: nil)
        self.binCount = binCount
        self.minUpdateInterval = minUpdateInterval
    }

    /// Throttled update: returns normalized bins (0..1) if an update was performed, or nil if throttled.
    func updateHistogramIfNeeded(for image: CIImage) -> [CGFloat]? {
        let now = CACurrentMediaTime()
        guard now - lastUpdate >= minUpdateInterval else {
            return nil
        }
        lastUpdate = now

        return computeHistogram(for: image)
    }

    /// Computes a 1D luminance histogram using CIAreaHistogram, normalized to 0..1.
    private func computeHistogram(for image: CIImage) -> [CGFloat]? {
        let filter = CIFilter.areaHistogram()
        filter.inputImage = image
        filter.extent = image.extent
        filter.scale = 1.0
        filter.count = binCount

        guard let outputImage = filter.outputImage else { return nil }

        var bins = [Float](repeating: 0, count: binCount)

        ciContext.render(
            outputImage,
            toBitmap: &bins,
            rowBytes: binCount * MemoryLayout<Float>.size,
            bounds: CGRect(x: 0, y: 0, width: binCount, height: 1),
            format: .Rf,
            colorSpace: nil
        )

        let maxValue = bins.max() ?? 0
        if maxValue <= 0 {
            return Array(repeating: 0, count: binCount).map(CGFloat.init)
        }

        return bins.map { CGFloat($0 / maxValue) }
    }
}

// MARK: - Luminance Histogram View

/// Draws a luminance histogram as a smooth polyline, with a vertical marker indicating
/// where the target exposure would land relative to the current camera exposure.
struct LuminanceHistogramView: View {
    let bins: [CGFloat]          // normalized 0..1, dark → bright
    let targetOffsetEV: Double   // EV offset between scene and settings (e.g. evDeltaValue)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Axes
                axesPath(in: geo.size)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)

                // Polyline
                Path { path in
                    guard bins.count > 1 else { return }

                    let width = geo.size.width
                    let height = geo.size.height
                    let stepX = width / CGFloat(bins.count - 1)

                    path.move(to: CGPoint(x: 0,
                                           y: height - bins[0] * height))

                    for (index, value) in bins.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - value * height
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.9), lineWidth: 1.5)

                // Target exposure marker
                markerPath(in: geo.size)
                    .stroke(Color.red.opacity(0.9),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }
        }
    }

    private func axesPath(in size: CGSize) -> Path {
        var path = Path()
        let width = size.width
        let height = size.height

        // Y-axis (left edge)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: height))

        // X-axis (bottom edge)
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: width, y: height))

        return path
    }

    private func markerPath(in size: CGSize) -> Path {
        var path = Path()
        guard bins.count > 1 else { return path }

        let width = size.width

        // Map EV offset to a bin index around the center.
        // Convention:
        // - targetOffsetEV > 0: settings darker than scene (histogram should shift left).
        // - targetOffsetEV < 0: settings brighter than scene (histogram should shift right).
        let scalePerEV: Double = 4.0  // tweak as desired
        let center = Double(bins.count - 1) / 2.0
        let targetEVRelative = -targetOffsetEV
        var targetIndex = center + targetEVRelative * scalePerEV
        targetIndex = max(0, min(Double(bins.count - 1), targetIndex))

        let x = CGFloat(targetIndex) / CGFloat(bins.count - 1) * width

        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
        return path
    }
}
