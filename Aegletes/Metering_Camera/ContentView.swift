//
//  ContentView.swift
//  Aegletes
//
//  Created by Nadir Pozegija on 3/3/26.
// //Revised 3/11/26. Added Permission overlays and session error logs

import SwiftUI
import UIKit

// Standard ISO ticks to style specially in the wheel
private func isStandardISO(_ value: Double) -> Bool {
    let standard: Set<Double> = [12, 25, 50, 100, 200, 400, 800, 1600, 3200, 6400]
    return standard.contains(value)
}

struct ContentView: View {
    @EnvironmentObject var filmStore: FilmRollStore
    
    @StateObject private var vm = AegletesViewModel()
    @State private var baseZoom: CGFloat = 1.0
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var showHistogram = false
    
    // Controls the "capture exposure" flow
    @State private var showingCaptureSheet = false
    
    /// Callback to switch to Film DB screen (set by RootView).
    var onShowFilmDB: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // CI-based preview in the back
            CameraPreview(feed: vm.camera)
                .onAppear {
                    vm.checkAndRequestCameraAuthorization()
                }
                .onDisappear {
                    vm.camera.stop()
                }
                .onChange(of: vm.cameraAuthState) { _, newValue in
                    if newValue == .authorized {
                        vm.camera.start()
                    } else {
                        vm.camera.stop()
                    }
                }
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
                // Top row: EV badge centered, Low Light warning directly under it, folder icon on right
                ZStack(alignment: .top) {
                    // Centered EV badge + Low Light Warning
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            EVBadge(evDelta: vm.evDeltaValue,
                                    isHistogramActive: showHistogram)
                            .onTapGesture {
                                showHistogram.toggle()
                                Haptics.histogramToggled()
                            }
                            
                            if vm.lowLightWarning {
                                Text("Warning: Low Light!")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.65))
                                    )
                                    .foregroundStyle(.red)
                                    .shadow(color: Color.red.opacity(0.5),
                                            radius: 4, x: 0, y: 2)
                            }
                        }
                        Spacer()
                    }
                    
                    // Right-aligned folder icon (Film DB)
                    HStack {
                        Spacer()
                        Button {
                            FilmDBHaptics.light()
                            onShowFilmDB?()
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.45))
                                )
                        }
                        .padding(.trailing, 12)
                    }
                }
                .padding(.top, 8)
                
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
                        // ISO picker (with styled "standard" ISO values)
                        let baseWheelHeight: CGFloat = 150
                        let lockTrade: CGFloat = 15
                        let wheelHeight = !vm.manualMode
                        ? (baseWheelHeight - lockTrade)   // shrink up a bit for locks
                        : (baseWheelHeight + lockTrade)   // expand down into lock space
                        
                        VStack(spacing: 6) {
                            Text("ISO")
                                .foregroundStyle(.white.opacity(0.8))
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                            
                            ZStack {
                                Picker("", selection: $vm.exposure.isoIndex) {
                                    ForEach(isoValues.indices, id: \.self) { idx in
                                        let value = isoValues[idx]
                                        let label = String(Int(value))
                                        
                                        Text(label)
                                            .fontWeight(isStandardISO(value) ? .bold : .regular)
                                            .foregroundStyle(
                                                isStandardISO(value)
                                                ? .white
                                                : .white.opacity(0.6)
                                            )
                                            .tag(idx)
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
                            if !vm.manualMode {
                                Button(action: {
                                    Haptics.lockToggled()
                                    vm.locks.iso.toggle()
                                }) {
                                    Image(systemName: vm.locks.iso ?
                                          "lock.fill" : "lock.open")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(
                                        Circle().fill(vm.locks.iso ?
                                                      Color.red : Color.gray)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 4)
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
                    
                    // Exposure mode selector: Light Meter vs Manual + Capture button
                    HStack(alignment: .top, spacing: 12) {
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
                                .foregroundStyle(.white)
                                .font(.caption)
                        }
                        
                        VStack {
                            // Capture exposure button
                            Button {
                                // Snapshot current exposure immediately
                                let iso = isoValues[vm.exposure.isoIndex]
                                let aperture = apertureValues[vm.exposure.apertureIndex]
                                let shutter = shutterValues[vm.exposure.shutterIndex]
                                
                                capturedExposure = CapturedExposureSnapshot(
                                    iso: iso,
                                    aperture: aperture,
                                    shutter: shutter,
                                    manualMode: vm.manualMode,
                                    sceneEV100: vm.sceneEV100Value,
                                    settingsEV100: vm.settingsEV100Value,
                                    evDelta: vm.evDeltaValue
                                )
                                Haptics.capture()
                                showingCaptureSheet = true
                            } label: {
                                Image(systemName: "pencil.and.list.clipboard")
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(8)
                                    .background(
                                        Circle().fill(Color.white.opacity(0.85))
                                    )
                                    .foregroundStyle(.black)
                            }
                            
                            Text("Add to Journal")
                                .foregroundStyle(.white)
                                .font(.caption)
                        }

                        Spacer()
                    }
                    .padding(.top, 8)
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
            
            // Camera permission overlay
            if vm.cameraAuthState == .denied || vm.cameraAuthState == .restricted {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    Text("Camera Access Needed")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Grant camera permission in Settings to use the light meter.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 24)
                    
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(Color.white)
                            )
                            .foregroundStyle(.black)
                    }
                }
            }
            
            // Camera runtime error / interruption overlay (only when authorized)
            if vm.cameraAuthState == .authorized &&
                (vm.camera.sessionInterrupted || vm.camera.sessionErrorMessage != nil) {
                
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                
                VStack(spacing: 10) {
                    if vm.camera.sessionInterrupted {
                        Text("Camera Temporarily Unavailable")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("Another app is using the camera or the system has paused capture.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary.opacity(0.8))
                            .padding(.horizontal, 24)
                    } else if let message = vm.camera.sessionErrorMessage {
                        Text("Camera Error")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text(message)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary.opacity(0.8))
                            .padding(.horizontal, 24)
                    }
                    
                    Button {
                        vm.camera.sessionErrorMessage = nil
                        vm.camera.sessionInterrupted = false
                        if vm.cameraAuthState == .authorized {
                            vm.camera.start()
                        }
                    } label: {
                        Text("Try Again")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(Color.white)
                            )
                            .foregroundStyle(.black)
                    }
                }
            }
        }
        //The sheet to show the scene notes that saves to the journal
        .sheet(isPresented: $showingCaptureSheet) {
            CaptureExposureSheet( loadedRolls: loadedRolls, isPresented: $showingCaptureSheet)
            { roll, frame, notes in
                captureExposure(to: roll, frame: frame, notes: notes)
            }
        }
    }
    
    // MARK: - Generic parameter picker (aperture & shutter)
    private func paramPicker(title: String,
                             values: [String],
                             selection: Binding<Int>,
                             locked: Bool,
                             showLock: Bool,
                             onLockToggle: @escaping () -> Void) -> some View {
        // Base wheel height and how much to trade with the lock space
        let baseWheelHeight: CGFloat = 150
        let lockTrade: CGFloat = 15
        let wheelHeight = showLock
        ? (baseWheelHeight - lockTrade)   // shrink up a bit for locks
        : (baseWheelHeight + lockTrade)   // expand down into lock space
        
        return VStack(spacing: 6) {
            // Title: fixed position, 16pt, semibold, serif
            Text(title)
                .foregroundStyle(.white.opacity(0.8))
                .font(.system(size: 16, weight: .semibold, design: .serif))
            
            // Wheel picker with center outline only (no filled highlight)
            ZStack {
                Picker("", selection: selection) {
                    ForEach(values.indices, id: \.self) { idx in
                        Text(values[idx])
                            .tag(idx)
                            .foregroundStyle(.white)
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
                    Image(systemName: locked ?
                          "lock.fill" : "lock.open")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(
                        Circle().fill(locked ?
                                      Color.red : Color.gray)
                    )
                }
            }
        }
        .padding(.horizontal, 4)
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
                .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(isManual ?
                                                         0.35 : 0.0))
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
        
        static func histogramToggled() {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        }
        
        static func capture() {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
    }
    
    // Capture function helper to filter loaded rolls
    private var loadedRolls: [FilmRoll] {
        filmStore.rolls.filter { $0.status == .loaded }
            .sorted { ($0.dateLoaded ?? .distantPast) > ($1.dateLoaded ?? .distantPast) }
    }
    
    // MARK: - Capture → Journal helper

    private func captureExposure(to roll: FilmRoll, frame: Int, notes: String) {
        
        //capture snapshot and use that for metadata if available
        let snapshot = capturedExposure
        let iso: Double
        let aperture: Double
        let shutter: Double
        let manualMode: Bool
        let sceneEV: Double
        let settingsEV: Double
        let delta: Double

        if let s = snapshot {
            iso = s.iso
            aperture = s.aperture
            shutter = s.shutter
            manualMode = s.manualMode
            sceneEV = s.sceneEV100
            settingsEV = s.settingsEV100
            delta = s.evDelta
        } else {
            // Fallback to live values if, for some reason, we have no snapshot
            iso = isoValues[vm.exposure.isoIndex]
            aperture = apertureValues[vm.exposure.apertureIndex]
            shutter = shutterValues[vm.exposure.shutterIndex]
            manualMode = vm.manualMode
            sceneEV = vm.sceneEV100Value
            settingsEV = vm.settingsEV100Value
            delta = vm.evDeltaValue
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let entry = FilmExposureEntry(
            frameNumber: frame,
            dateCaptured: Date(),
            iso: iso,
            aperture: aperture,
            shutter: shutter,
            manualMode: manualMode,
            sceneEV100: sceneEV,
            settingsEV100: settingsEV,
            evDelta: delta,
            notes: trimmedNotes
        )

        // Use the latest copy of this roll from the store,
        // then update and persist it via FilmRollStore.
        guard var latest = filmStore.rolls.first(where: { $0.id == roll.id }) else { return }
        
        // Safety: prevent multiple journal entries for the same frame
        if latest.journal.contains(where: { $0.frameNumber == frame })
        { return }
        latest.journal.append(entry)
        filmStore.updateRoll(latest)
    }
    
    // capture snapshot of the exposure settings the moment the user taps the button
    @State private var capturedExposure: CapturedExposureSnapshot?
    private struct CapturedExposureSnapshot {
        let iso: Double
        let aperture: Double
        let shutter: Double
        let manualMode: Bool
        let sceneEV100: Double
        let settingsEV100: Double
        let evDelta: Double
    }
}
