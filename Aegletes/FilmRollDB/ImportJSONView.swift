///  ImportJSONView.swift
//   Aegletes
//
//   Wraps UIDocumentPickerViewController to import a Film DB JSON.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportJSONView: UIViewControllerRepresentable {
    /// Called with the picked file URL (or nil if cancelled).
    let onPick: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let utTypeJSON = UTType.json
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [utTypeJSON])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void

        init(onPick: @escaping (URL?) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}
