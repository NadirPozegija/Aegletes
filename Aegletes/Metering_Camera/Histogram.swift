//
// Histogram.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/6/26.
// Rev: 7 (GPU brightness histogram + bar view, percent y-axis, center reference marker)
//

import Foundation
import CoreImage
import SwiftUI

// MARK: - Luminance Histogram View (bars)
/// Draws a brightness histogram as vertical bars, with:
/// - X-axis: brightness bins from dark → bright (no labels).
/// - Y-axis: percent of pixels in each bin (0–100%), dynamically scaled with ~5% headroom.
/// - A green center reference marker (0 EV delta).
/// - A red dashed marker indicating EV delta between scene and settings.
struct LuminanceHistogramView: View {
    /// 0..1 = 0–100% of pixels in each brightness bin, left → right dark → bright.
    let bins: [CGFloat]
    /// EV offset between scene and settings (e.g. evDeltaValue) used for the red marker.
    let targetOffsetEV: Double

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let width = size.width
            let height = geo.size.height

            // Dynamic y-axis top: ~5% above tallest bin, capped at 100%.
            let maxBin = bins.max() ?? 0
            let axisMax = min(1.0, maxBin * 1.05)

            ZStack {
                // Axes
                axesPath(in: size)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)

                // Bars for each brightness bin
                if axisMax > 0, bins.count > 0 {
                    let barWidth = width / CGFloat(bins.count)

                    ForEach(bins.indices, id: \.self) { index in
                        let value = bins[index]
                        let normalized = max(0, min(1, value / axisMax))
                        let barHeight = normalized * height

                        Path { path in
                            let x = CGFloat(index) * barWidth
                            let y = height - barHeight
                            path.addRect(
                                CGRect(
                                    x: x,
                                    y: y,
                                    width: barWidth,
                                    height: barHeight
                                )
                            )
                        }
                        .fill(Color.white.opacity(0.9))
                    }
                }

                // Green center reference marker (0 EV delta)
                centerMarkerPath(in: size)
                    .stroke(Color.green.opacity(0.9), lineWidth: 1)

                // Red EV delta marker (relative to center)
                markerPath(in: size)
                    .stroke(
                        Color.red.opacity(0.9),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                    )

                // Y-axis labels in percent
                VStack {
                    HStack {
                        Text("\(Int(axisMax * 100))%")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Text("0%")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                }
                .padding(2)
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

    /// Green reference marker at the center of the histogram (EV Δ = 0 reference).
    private func centerMarkerPath(in size: CGSize) -> Path {
        var path = Path()
        let width = size.width
        let centerX = width / 2.0
        path.move(to: CGPoint(x: centerX, y: 0))
        path.addLine(to: CGPoint(x: centerX, y: size.height))
        return path
    }

    /// Red marker showing EV delta between scene and settings, mapped around center.
    private func markerPath(in size: CGSize) -> Path {
        var path = Path()
        guard bins.count > 1 else { return path }

        let width = size.width

        // Map EV offset to a bin index around the center.
        // Convention:
        // - targetOffsetEV > 0: settings darker than scene (histogram should shift right).
        // - targetOffsetEV < 0: settings brighter than scene (histogram should shift left).
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
