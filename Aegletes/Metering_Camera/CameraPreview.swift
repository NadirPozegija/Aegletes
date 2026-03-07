//
// CameraPreview.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/3/26.
// Edited on 3/5/26 - Revision 3
//

import SwiftUI
import UIKit

final class CIImagePreviewView: UIView {
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var feed: CameraFeed

    func makeUIView(context: Context) -> CIImagePreviewView {
        CIImagePreviewView()
    }

    func updateUIView(_ uiView: CIImagePreviewView, context: Context) {
        if let cgImage = feed.previewFrame {
            uiView.imageView.image = UIImage(cgImage: cgImage)
        }
    }
}
