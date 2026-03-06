//
// ContentView.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/5/26 - Revision 18
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = AegletesViewModel()
    @State private var baseZoom: CGFloat = 1.0
    @GestureState private var pinchScale: CGFloat = 1.0

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
                // EV Δ badge at top-center
                EVBadge(evDelta: vm.evDeltaValue)
                    .padding(.top, 8)

                Spacer()

                // Bottom controls
                VStack {
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

                    // Exposure mode selector: Light Meter vs Manual
                    HStack {
                        Spacer()

                        VStack(spacing: 4) {
                            Picker(
                                "",
                                selection: Binding(
                                    get: { vm.manualMode ? 1 : 0 },
                                    set: { vm.setManualMode($0 == 1) }
                                )
                            ) {
                                Text("Light Meter").tag(0)
                                Text("Manual").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .tint(vm.manualMode ? Color.orange : Color.accentColor)
                            .frame(maxWidth: 260)

                            Text("Exposure Mode")
                                .foregroundColor(.white)
                                .font(.caption)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Color.black.opacity(0.6)) // solid dark panel extended to bottom
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
            }
            .padding(.bottom, 0) // no gap at the bottom
            .zIndex(1)
        }
    }

    private func paramPicker(title: String,
                             values: [String],
                             selection: Binding<Int>,
                             locked: Bool,
                             showLock: Bool,
                             onLockToggle: @escaping () -> Void) -> some View {

        VStack(spacing: 6) {
            // Caption label
            Text(title)
                .foregroundColor(.white.opacity(0.8))
                .font(.caption)

            // Wheel picker with center outline only (no filled highlight)
            ZStack {
                Picker("", selection: selection) {
                    ForEach(values.indices, id: \.self) { idx in
                        Text(values[idx]).tag(idx)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: 90, height: 150)

                // Center outline band (no fill)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    .frame(height: 32)
            }

            // Lock icon button
            if showLock {
                Button(action: onLockToggle) {
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
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 2)
    }
}
