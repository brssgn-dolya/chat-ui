//
//  CameraModal.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 08.11.2025.
//

import SwiftUI
import AVFoundation

enum CapturedMedia {
    case photo(UIImage)
    case video(URL)
}

struct CameraModal: View {
    @Binding var isPresented: Bool
    let onMediaPicked: (CapturedMedia) -> Void

    @State private var permission: AVAuthorizationStatus = .notDetermined

    var body: some View {
        ZStack {
            switch permission {
            case .authorized:
                SystemCameraPickerContent(
                    isPresented: $isPresented,
                    onMediaPicked: onMediaPicked
                )
                .ignoresSafeArea()

            case .denied, .restricted:
                CameraPermissionView(
                    title: "Дозвольте доступ до Камери",
                    subtitle: "Щоб знімати фото/відео, увімкніть доступ до камери в Налаштуваннях.",
                    onOpenSettings: openSettings,
                    onNotNow: { isPresented = false },
                    onClose: { isPresented = false }
                )
                .ignoresSafeArea()

            case .notDetermined:
                ProgressView()
                    .onAppear { requestOrRefreshPermission() }
                    .ignoresSafeArea()

            @unknown default:
                CameraPermissionView(
                    title: "Дозвольте доступ до Камери",
                    subtitle: "Щоб знімати фото/відео, увімкніть доступ до камери в Налаштуваннях.",
                    onOpenSettings: openSettings,
                    onNotNow: { isPresented = false },
                    onClose: { isPresented = false }
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            requestOrRefreshPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            requestOrRefreshPermission()
        }
    }

    private func requestOrRefreshPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permission = status

        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    permission = granted ? .authorized : .denied
                }
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct SystemCameraPickerContent: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onMediaPicked: (CapturedMedia) -> Void
    
    var cameraDevice: UIImagePickerController.CameraDevice = .rear
    var initialCaptureMode: UIImagePickerController.CameraCaptureMode = .photo
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        
        if UIImagePickerController.isCameraDeviceAvailable(cameraDevice) {
            picker.cameraDevice = cameraDevice
        }
        
        picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera)
        ?? ["public.image", "public.movie"]
        
        picker.cameraCaptureMode = initialCaptureMode
        picker.videoQuality = .typeHigh
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SystemCameraPickerContent
        
        init(parent: SystemCameraPickerContent) { self.parent = parent }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
        
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onMediaPicked(.photo(image))
            } else if let mediaURL = info[.mediaURL] as? URL {
                parent.onMediaPicked(.video(mediaURL))
            }
            parent.isPresented = false
        }
    }
}
