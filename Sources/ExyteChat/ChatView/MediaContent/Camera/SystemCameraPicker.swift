//
//  SystemCameraPicker.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 08.11.2025.
//

import SwiftUI

enum CapturedMedia {
    case photo(UIImage)
    case video(URL)
}

struct SystemCameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onMediaPicked: (CapturedMedia) -> Void
    var cameraDevice: UIImagePickerController.CameraDevice = .rear
    var initialCaptureMode: UIImagePickerController.CameraCaptureMode = .photo

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            DispatchQueue.main.async { isPresented = false }
            return picker
        }

        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false

        if UIImagePickerController.isCameraDeviceAvailable(cameraDevice) {
            picker.cameraDevice = cameraDevice
        }

        if let available = UIImagePickerController.availableMediaTypes(for: .camera) {
            picker.mediaTypes = available
        } else {
            picker.mediaTypes = ["public.image", "public.movie"]
        }

        picker.cameraCaptureMode = initialCaptureMode
        picker.videoQuality = .typeHigh
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SystemCameraPicker

        init(parent: SystemCameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onMediaPicked(.photo(image))
            } else if let mediaURL = info[.mediaURL] as? URL {
                parent.onMediaPicked(.video(mediaURL))
            }
            parent.isPresented = false
        }
    }
}
