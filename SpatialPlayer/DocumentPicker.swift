//
//  DocumentPicker.swift
//  SpatialPlayer
//
//  Created by Michael Swanson on 2/6/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.movie])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(
            _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
        ) {
            guard let selectedURL = urls.first else {
                print("No document selected")
                return
            }
            parent.viewModel.videoURL = URL(string: "https://private.ateme-ri.com/VhObLtUMFf/ref/clear/hls/master.m3u8")
            parent.viewModel.isDocumentPickerPresented = false
            parent.viewModel.isImmersiveSpaceShown = true
        }
    }
}
