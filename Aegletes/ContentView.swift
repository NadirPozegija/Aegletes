//
// ContentView.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/5/26 - Revision 7
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = AegletesViewModel()
    @State private var baseZoom: CGFloat = 1.0
    @GestureState private var pinchScale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            VStack {
                // EV display (top-center)
                Text(String(format: "EV = %+0.1f", vm.evDeltaValue))
                    .font(.headline)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()

                Spacer()

                // Bottom controls
                VStack {
                    HStack {
                        // ISO picker
                        paramPicker(
                            title: "ISO",
                            values: isoValues.map { value in
                                String(Int(value)) // simpler to read values
                            },
                            selection: $vm.exposure.isoIndex,
                            locked: vm.locks.iso,
                            showLock: !vm.manualMode,
                            onLockToggle: { vm.locks.iso.toggle() }
                        )
                        .onChange(of: vm.exposure.isoIndex) { _, _ in
                            if vm.manualMode {
                                // Manual: directly apply wheels to camera, no auto logic
                                vm.applyPickersToCamera()
                            } else {
                                // Light meter mode: re-run auto logic
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
                                // Aperture is conceptual only; still allow user to change it,
                                // but no automatic adjustments in manual mode
                                vm.applyPickersToCamera()
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
                                vm.applyPickersToCamera()
                            } else {
                                vm.updateForNewSceneEV()
                            }
                        }
                    }
                    .frame(height: 180)

                    // Mode selector: light meter (auto) vs full manual exposure
                    HStack {
                        Spacer()

                        VStack(spacing: 4) {
                            Text("Exposure Mode")
                                .foregroundColor(.white)
                                .font(.caption)

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
                            .frame(maxWidth: 260)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color.black.opacity(0.6))
            }
        }
    }

    private func paramPicker(title: String,
                             values: [String],
                             selection: Binding<Int>,
                             locked: Bool,
                             showLock: Bool,
                             onLockToggle: @escaping () -> Void) -> some View {

        VStack {
            Text(title).foregroundColor(.white)
            Picker("", selection: selection) {
                ForEach(values.indices, id: \.self) { idx in
                    Text(values[idx]).tag(idx)
                }
            }
            .labelsHidden()
            .pickerStyle(.wheel)
            // Wheels are never disabled; locks only affect auto logic in light meter mode.

            if showLock {
                Button(locked ? "Unlock" : "Lock") {
                    onLockToggle()
                }
                .font(.caption)
                .padding(4)
                .background(locked ? Color.red : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 4)
    }
}
