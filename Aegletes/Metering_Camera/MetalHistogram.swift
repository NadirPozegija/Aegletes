//
// MetalHistogram.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/7/26.
//

import Foundation
import Metal
import CoreVideo
import QuartzCore

final class MetalHistogram {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLComputePipelineState
    private let binCount: Int = 256
    private let minUpdateInterval: CFTimeInterval
    private var lastUpdate: CFTimeInterval = 0

    private var textureCache: CVMetalTextureCache?
    private let histogramBuffer: MTLBuffer

    init?(minUpdateInterval: CFTimeInterval = 0.1) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue()
        else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.minUpdateInterval = minUpdateInterval

        // Load compute function from default library
        guard
            let library = device.makeDefaultLibrary(),
            let function = library.makeFunction(name: "lumaHistogramKernel")
        else {
            return nil
        }

        do {
            pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            return nil
        }

        // Create histogram buffer (256 uints)
        let length = binCount * MemoryLayout<UInt32>.stride
        guard let buffer = device.makeBuffer(length: length, options: [.storageModeShared]) else {
            return nil
        }
        histogramBuffer = buffer

        // Create CVMetal texture cache
        var cache: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        if result != kCVReturnSuccess || cache == nil {
            return nil
        }
        textureCache = cache
    }

    /// Throttled update: returns brightness bins as fractions of total pixels (0..1),
    /// or nil if throttled or any step fails.
    func updateHistogramIfNeeded(from pixelBuffer: CVPixelBuffer) -> [CGFloat]? {
        let now = CACurrentMediaTime()
        guard now - lastUpdate >= minUpdateInterval else {
            return nil
        }

        guard let texture = makeTexture(from: pixelBuffer) else {
            return nil
        }

        // Zero histogram buffer
        memset(histogramBuffer.contents(), 0, histogramBuffer.length)

        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(histogramBuffer, offset: 0, index: 0)

        let width = pipelineState.threadExecutionWidth
        let height = pipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)

        let tgWidth = (texture.width  + width  - 1) / width
        let tgHeight = (texture.height + height - 1) / height
        let threadgroups = MTLSize(width: tgWidth, height: tgHeight, depth: 1)

        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        lastUpdate = now

        // Read back and normalize to fractions
        let ptr = histogramBuffer.contents().bindMemory(to: UInt32.self, capacity: binCount)
        var counts = [UInt32](repeating: 0, count: binCount)
        for i in 0..<binCount {
            counts[i] = ptr[i]
        }

        let total = counts.reduce(0, +)
        guard total > 0 else {
            return Array(repeating: 0, count: binCount).map(CGFloat.init)
        }

        let totalF = Double(total)
        return counts.map { CGFloat(Double($0) / totalF) }
    }

    private func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let cache = textureCache else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard result == kCVReturnSuccess,
              let cvTex = cvTexture,
              let texture = CVMetalTextureGetTexture(cvTex)
        else {
            return nil
        }

        return texture
    }
}
