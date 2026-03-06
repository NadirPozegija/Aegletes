//
// ContentView.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/6/26 - Revision 29 (Histogram layout + EV badge state)
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var vm = AegletesViewModel()
    @State private var baseZoom: CGFloat = 1.0
    @GestureState private var pinchScale: CGFloat = 1.0

    @State private var showHistogram = false

    var body: some View {
        ZStack {
            // CI-based preview in the back
            CameraPreview(feed: vm.camera)
                .onAppear { vm.camera.start() }
                .onDisappear { vm.camera.stop() }
                .gesture(
                    MagnificationGesture()
                        .updating($pinchScale) { value, state, _ in
                            state = value
                            let newZoom = baseZoom * value
                            vm.camera.setZoom(factor: newZoom)
                        }
                        .onEnded { value in
                            baseZoom *= value
                            if baseZoom < 1.0 { baseZoom = 1.0 }
                        }
                )
                .ignoresSafeArea()
                .zIndex(0)

            // UI overlays
            VStack {
                // EV Δ badge at top-center (tap to toggle histogram)
                EVBadge(evDelta: vm.evDeltaValue,
                        isHistogramActive: showHistogram)
                    .padding(.top, 8)
                    .onTapGesture {
                        showHistogram.toggle()
                    }

                Spacer()

                // Histogram sitting directly above the bottom panel
                if showHistogram {
                    LuminanceHistogramView(
                        bins: vm.camera.histogramBins,
                        targetOffsetEV: vm.evDeltaValue
                    )
                    .frame(height: 80)
                    .padding(.horizontal, 12)
                    .transition(.opacity)
                }

                // Bottom controls
                VStack {
                    // Wheels row with fixed height (panel stays static)
                    HStack(alignment: .top) {
                        // ISO picker
                        paramPicker(
                            title: "ISO",
                            values: isoValues.map { String(Int($0)) },
                            selection: $vm.exposure.isoIndex,
                            locked: vm.locks.iso,
                            showLock: !vm.manualMode,
                            onLockToggle: { vm.locks.iso.toggle() }
                        )
                        .onChange(of: vm.exposure.isoIndex) { _, _ in
                            if vm.manualMode {
                                vm.updatePreviewEVOffsetIfNeeded()
                            } else {
                                vm.updateForNewSceneEV()
                            }
                        }

                        // Aperture picker
                        paramPicker(
                            title: "f/stop",
                            values: apertureValues.map { "f/\($0)" },
                            selection: $vm.exposure.apertureIndex,
                            locked: vm.locks.aperture,
                            showLock: !vm.manualMode,
                            onLockToggle: { vm.locks.aperture.toggle() }
                        )
                        .onChange(of: vm.exposure.apertureIndex) { _, _ in
                            if vm.manualMode {
                                vm.updatePreviewEVOffsetIfNeeded()
                            } else {
                                vm.updateForNewSceneEV()
                            }
                        }

                        // Shutter picker
                        paramPicker(
                            title: "s",
                            values: shutterValues.map { value in
                                if value < 1 {
                                    return "1/\(Int(round(1.0 / value)))"
                                } else {
                                    return "\(Int(round(value)))"
                                }
                            },
                            selection: $vm.exposure.shutterIndex,
                            locked: vm.locks.shutter,
                            showLock: !vm.manualMode,
                            onLockToggle: { vm.locks.shutter.toggle() }
                        )
                        .onChange(of: vm.exposure.shutterIndex) { _, _ in
                            if vm.manualMode {
                                vm.updatePreviewEVOffsetIfNeeded()
                            } else {
                                vm.updateForNewSceneEV()
                            }
                        }
                    }
                    .frame(height: 190)  // fixed row height; wheels adjust within this

                    // Exposure mode selector: Light Meter vs Manual
                    HStack {
                        Spacer()

                        VStack(spacing: 6) {
                            ModeSelector(
                                isManual: Binding(
                                    get: { vm.manualMode },
                                    set: { vm.setManualMode($0) }
                                )
                            )
                            .frame(maxWidth: 260)

                            Text("Exposure Mode")
                                .foregroundColor(.white)
                                .font(.caption)
                        }

                        Spacer()
                    }
                    .padding(.top, 4)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Color.black.opacity(0.6))
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
            }
            .padding(.bottom, 0)
            .zIndex(1)
        }
    }

    private func paramPicker(title: String,
                             values: [String],
                             selection: Binding<Int>,
                             locked: Bool,
                             showLock: Bool,
                             onLockToggle: @escaping () -> Void) -> some View {

        // Base wheel height and how much to trade with the lock space
        let baseWheelHeight: CGFloat = 150
        let lockTrade: CGFloat = 15
        let wheelHeight = showLock ? (baseWheelHeight - lockTrade)   // shrink up a bit for locks
                                   : (baseWheelHeight + lockTrade)   // expand down into lock space

        return VStack(spacing: 6) {
            // Title: fixed position, 16pt, semibold, serif
            Text(title)
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 16, weight: .semibold, design: .serif))

            // Wheel picker with center outline only (no filled highlight)
            ZStack {
                Picker("", selection: selection) {
                    ForEach(values.indices, id: \.self) { idx in
                        Text(values[idx]).tag(idx)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: 90, height: wheelHeight)

                // Center outline band (no fill)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    .frame(height: 32)
            }

            // Lock icon button (Light Meter mode only)
            if showLock {
                Button(action: {
                    Haptics.lockToggled()
                    onLockToggle()
                }) {
                    Image(systemName: locked ? "lock.fill" : "lock.open")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(
                            Circle().fill(locked ? Color.red : Color.gray)
                        )
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - EV Badge

private struct EVBadge: View {
    let evDelta: Double
    let isHistogramActive: Bool

    var body: some View {
        let text = String(format: "EV Δ = %+0.1f", evDelta)

        Text(text)
            .font(.system(size: 17, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.45))
            )
            .overlay(
                Capsule()
                    .stroke(
                        isHistogramActive
                        ? Color.green.opacity(0.9)
                        : Color.white.opacity(0.35),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Mode Selector (custom tinted segments)

private struct ModeSelector: View {
    @Binding var isManual: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Light Meter segment
            Button {
                if isManual {
                    isManual = false
                    Haptics.modeChanged()
                }
            } label: {
                Text("Light Meter")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(isManual ? 0.0 : 0.35))
                    )
            }
            .buttonStyle(.plain)

            // Manual segment
            Button {
                if !isManual {
                    isManual = true
                    Haptics.modeChanged()
                }
            } label: {
                Text("Manual")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(isManual ? 0.35 : 0.0))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(2)
        .background(
            Capsule()
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Haptics

private enum Haptics {
    static func modeChanged() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    static func lockToggled() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
