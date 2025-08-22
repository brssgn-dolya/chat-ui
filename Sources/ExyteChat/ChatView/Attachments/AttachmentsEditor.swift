//
//  AttachmentsEditor.swift
//  Chat
//
//  Created by Alex.M on 22.06.2022.
//

import SwiftUI
import ExyteMediaPicker
import ActivityIndicatorView
import AVFoundation

struct AttachmentsEditor<InputViewContent: View>: View {

    typealias InputViewBuilderClosure = ChatView<EmptyView, InputViewContent, DefaultMessageMenuAction>.InputViewBuilderClosure

    @Environment(\.chatTheme) var theme
    @Environment(\.mediaPickerTheme) var pickerTheme

    @EnvironmentObject private var keyboardState: KeyboardState
    @EnvironmentObject private var globalFocusState: GlobalFocusState

    @ObservedObject var inputViewModel: InputViewModel
    @ObservedObject private var mentionsViewModel = MentionsSuggestionsViewModel()
    
    var inputViewBuilder: InputViewBuilderClosure?
    var chatTitle: String?
    var messageUseMarkdown: Bool
    var orientationHandler: MediaPickerOrientationHandler
    var mediaPickerSelectionParameters: MediaPickerParameters?
    var availableInput: AvailableInputType

    @State private var seleсtedMedias: [Media] = []
    @State private var currentFullscreenMedia: Media?

    // Recording state
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var cameraMode: CameraMode = .photo

    // Camera state tracking
    @State private var isSwitchingCamera = false
    @State private var isTogglingFlash = false
    @State private var cameraPosition: AVCaptureDevice.Position = .back

    @State private var isTorchOn = false

    var showingAlbums: Bool {
        inputViewModel.mediaPickerMode == .albums
    }

    var body: some View {
        ZStack {
            mediaPicker

            if inputViewModel.showActivityIndicator {
                ActivityIndicator()
            }
        }
        .onDisappear { stopRecordingTimer() }
        .onChange(of: cameraMode) { _, newMode in
            if newMode == .photo, isRecording {
                stopRecordingTimer()
            }
        }
    }
    
    private func toggleFlashSafe(_ toggleFlash: @escaping () -> Void) {
        guard !isTogglingFlash, !isRecording else { return }
        isTogglingFlash = true
        
        // Оновлюємо стан спалаху
        let newTorchState = !isTorchOn
        isTorchOn = newTorchState
        
        toggleFlash()
        
        // Скидаємо прапор після виконання дії
        isTogglingFlash = false
    }

    private func switchCameraSafe(_ switchCamera: @escaping () -> Void) {
        guard !isRecording else {
            print("⚠️ Не можу перемкнути камеру: isSwitchingCamera=\(isSwitchingCamera), isRecording=\(isRecording)")
            return
        }
        
        isSwitchingCamera = true
        print("🔄 Початок перемикання камери")
        
        // Нова позиція (очікувана)
        let newPosition: AVCaptureDevice.Position = cameraPosition == .back ? .front : .back
        cameraPosition = newPosition
        print("📷 Очікувана позиція камери: \(newPosition == .back ? "задня" : "передня")")
        
        // retry-цикл
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            switchCamera()
            print("🔁 Спроба перемикання №\(attempt)")
        }
        
        isSwitchingCamera = false
        print("✅ Перемикання камери завершено")
    }

    var albumSelectionHeaderView: some View {
        ZStack {
            HStack {
                Button {
                    seleсtedMedias = []
                    inputViewModel.showPicker = false
                } label: {
                    Text("Скасувати")
                }

                Spacer()
            }

            HStack {
                Text("Останні")
                Image(systemName: "chevron.down")
                    .rotationEffect(Angle(radians: showingAlbums ? .pi : 0))
            }
            .onTapGesture {
                withAnimation {
                    inputViewModel.mediaPickerMode = showingAlbums ? .photos : .albums
                }
            }
            .frame(maxWidth: .infinity)
        }
        .foregroundColor(.primary)
        .padding(.horizontal)
        .padding(.bottom, 5)
    }

    // MARK: - MediaPicker
    var mediaPicker: some View {
        GeometryReader { g in
            MediaPicker(isPresented: $inputViewModel.showPicker) {
                seleсtedMedias = $0
                assembleSelectedMedia()
            } albumSelectionBuilder: { _, albumSelectionView, _ in
                ZStack {
                    VStack(spacing: 0) {
                        albumSelectionHeaderView
                            .padding(.top, g.safeAreaInsets.top > 0 ? g.safeAreaInsets.top : 20)
                            .padding(.bottom, 8)
                        albumSelectionView
                        Spacer()
                        inputView
                            .padding(.bottom, g.safeAreaInsets.bottom > 0 ? g.safeAreaInsets.bottom : 20)
                    }
                    .background(pickerTheme.main.pickerBackground)

                    if isRecording {
                        RecordingTimerView(elapsedTime: recordingTime)
                            .position(
                                x: g.size.width / 2,
                                y: (g.safeAreaInsets.top > 0 ? g.safeAreaInsets.top : 20) + 50
                            )
                    }
                }
                .ignoresSafeArea()
            } cameraSelectionBuilder: { _, cancelClosure, cameraSelectionView in
                ZStack {
                    VStack(spacing: 0) {
                        headerCloseOnly(
                            topInset: g.safeAreaInsets.top > 0 ? g.safeAreaInsets.top : 20,
                            title: chatTitle,
                            onClose: {
                                cancelClosure()
                                stopRecordingTimer()
                            }
                        )

                        cameraSelectionView

                        cameraBottomControls(
                            safeBottomInset: g.safeAreaInsets.bottom,
                            onShowPreview: nil
                        )
                    }

                    if isRecording {
                        RecordingTimerView(elapsedTime: recordingTime)
                            .position(x: g.size.width / 2, y: (g.safeAreaInsets.top > 0 ? g.safeAreaInsets.top : 20) + 50)
                    }
                }
                .ignoresSafeArea()
            } cameraViewBuilder: { liveCamera, cancel, showPreview, takePhoto, startRecord, stopRecord, toggleFlash, switchCamera in
                GeometryReader { geometry in
                    ZStack {
                        liveCamera
                            .ignoresSafeArea()

                        // TOP: close only
                        VStack {
                            HStack {
                                Button(action: {
                                    cancel()
                                    stopRecordingTimer()
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                }
                                .padding(.leading, 16)
                                .padding(.top, 48)

                                Spacer()
                            }
                            Spacer()
                        }

                        // BOTTOM: all controls
                        VStack(spacing: 12) {
                            Spacer()

                            if isRecording {
                                RecordingTimerView(elapsedTime: recordingTime)
                                    .padding(.bottom, 4)
                            }

                            // Mode switch (Photo / Video)
                            HStack(spacing: 10) {
                                modeChip(title: "ФОТО", active: cameraMode == .photo) {
                                    if isRecording { stopRecordingTimer() }
                                    cameraMode = .photo
                                }
                                modeChip(title: "ВІДЕО", active: cameraMode == .video) {
                                    cameraMode = .video
                                }
                            }
                            .padding(.horizontal, 16)

                            // Main control bar
                            HStack {
                                Button(action: {
                                    if isRecording { stopRecordingTimer() }
                                    inputViewModel.mediaPickerMode = .albums
                                }) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                }
                                .accessibilityLabel("Відкрити галерею")

                                Spacer(minLength: 24)

                                Button(action: {
                                    guard !isSwitchingCamera, !isTogglingFlash else { return }
                                    if cameraMode == .photo {
                                        takePhoto()
                                    } else {
                                        if isRecording {
                                            stopRecord()
                                            stopRecordingTimer()
                                        } else {
                                            startRecord()
                                            startRecordingTimer()
                                        }
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(isRecording ? Color.red : Color.white)
                                            .frame(width: 70, height: 70)

                                        if isRecording {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.white)
                                                .frame(width: 20, height: 20)
                                        } else {
                                            Circle()
                                                .stroke(Color.black, lineWidth: 3)
                                                .frame(width: 60, height: 60)
                                        }
                                    }
                                }

                                Spacer(minLength: 24)

                                // Flash + Switch camera (right, stacked)
                                VStack(spacing: 14) {
                                    Button(action: {
                                        toggleFlashSafe(toggleFlash)
                                    }) {
                                        Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(Circle().fill(Color.black.opacity(0.6)))
                                    }
//                                    .disabled(isTogglingFlash || isRecording)
//                                    .opacity((isTogglingFlash || isRecording) ? 0.5 : 1.0)
                                    .opacity(0.0)
                                    .accessibilityLabel(isTorchOn ? "Вимкнути спалах" : "Увімкнути спалах")

                                    Button(action: {
                                        switchCameraSafe(switchCamera)
                                    }) {
                                        Image(systemName: cameraPosition == .front ? "camera.rotate.fill" : "camera.rotate")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(Circle().fill(Color.black.opacity(0.6)))
                                    }
//                                    .disabled(isSwitchingCamera || isRecording)
//                                    .opacity((isSwitchingCamera || isRecording) ? 0.5 : 1.0)
                                    .opacity(0.0)
                                    .accessibilityLabel("Перемкнути камеру")
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom + 12 : 28)
                        }
                    }
                }
            }
            .didPressCancelCamera {
                inputViewModel.showPicker = false
                stopRecordingTimer()
            }
            .currentFullscreenMedia($currentFullscreenMedia)
            .showLiveCameraCell()
            .setSelectionParameters(mediaPickerSelectionParameters)
            .pickerMode($inputViewModel.mediaPickerMode)
            .orientationHandler(orientationHandler)
            .background(pickerTheme.main.pickerBackground)
            .ignoresSafeArea(.all)
            .onChange(of: currentFullscreenMedia) { _, _ in
                assembleSelectedMedia()
            }
            .onChange(of: inputViewModel.showPicker) { _, newValue in
                let showFullscreenPreview = mediaPickerSelectionParameters?.showFullscreenPreview ?? true
                let selectionLimit = mediaPickerSelectionParameters?.selectionLimit ?? 1

                if selectionLimit == 1 && !showFullscreenPreview {
                    assembleSelectedMedia()
                    inputViewModel.send()
                }
                if !newValue {
                    stopRecordingTimer()
                    isSwitchingCamera = false
                    isTogglingFlash = false
                }
            }
        }
    }

    // MARK: - Helpers

    func assembleSelectedMedia() {
        if !seleсtedMedias.isEmpty {
            inputViewModel.attachments.medias = seleсtedMedias
        } else if let media = currentFullscreenMedia {
            inputViewModel.attachments.medias = [media]
        } else {
            inputViewModel.attachments.medias = []
        }
    }

    private func startRecordingTimer() {
        stopRecordingTimer()
        isRecording = true
        recordingTime = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async { self.recordingTime += 0.1 }
        }
    }

    private func stopRecordingTimer() {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    // MARK: - UI Pieces

    private func headerCloseOnly(topInset: CGFloat, title: String? = nil, onClose: @escaping () -> Void) -> some View {
        ZStack {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(8)
                }
                Spacer()
            }
            if let title {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, topInset)
        .padding(.bottom, 12)
        .background(Color(.systemBackground).opacity(0.9))
    }

    private func cameraBottomControls(safeBottomInset: CGFloat, onShowPreview: (() -> Void)?) -> some View {
        VStack(spacing: 8) {
            inputView
                .padding(.bottom, safeBottomInset > 0 ? safeBottomInset : 20)
        }
    }

    private func modeChip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(active ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(active ? Color.blue : Color.black.opacity(0.35))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recording Timer View
struct RecordingTimerView: View {
    let elapsedTime: TimeInterval

    var body: some View {
        Text(timeString)
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.85))
            .cornerRadius(8)
            .shadow(radius: 5)
    }

    private var timeString: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let milliseconds = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}

enum CameraMode { case photo, video }

extension AttachmentsEditor {
    @ViewBuilder
    var inputView: some View {
        Group {
            if let inputViewBuilder = inputViewBuilder {
                inputViewBuilder(
                    $inputViewModel.text,
                    inputViewModel.attachments,
                    inputViewModel.state,
                    .signature,
                    inputViewModel.inputViewAction()
                ) {
                    globalFocusState.focus = nil
                }
            } else {
                InputView(
                    mentionsViewModel: mentionsViewModel,
                    viewModel: inputViewModel,
                    inputFieldId: UUID(),
                    style: .signature,
                    availableInput: availableInput,
                    messageUseMarkdown: messageUseMarkdown
                )
                .padding(.horizontal, 16)
            }
        }
    }
}
