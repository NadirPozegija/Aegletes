////  ExportJSONView.swift
//   Aegletes
//
//   Wraps UIActivityViewController to export the Film DB JSON.
//

import SwiftUI

struct ExportJSONView: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // nothing to update
    }
}
