//
// CameraPreview.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var feed: CameraFeed

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = feed.makePreviewLayer()
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer else {
            return
        }
        layer.frame = uiView.bounds
    }
}
