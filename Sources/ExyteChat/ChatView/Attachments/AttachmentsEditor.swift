//
//  AttachmentsEditor.swift
//  Chat
//
//  Created by Alex.M on 22.06.2022.
//

import SwiftUI
import ExyteMediaPicker
import ActivityIndicatorView

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
    @Binding var mediaPickerMode: MediaPickerMode

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
    }

    var mediaPicker: some View {
        GeometryReader { g in
            MediaPicker(isPresented: $inputViewModel.showPicker) {
                seleсtedMedias = $0
                assembleSelectedMedia()
            } albumSelectionBuilder: { _, albumSelectionView, _ in
                VStack {
                    albumSelectionHeaderView
                        .padding(.top, g.safeAreaInsets.top)
                    albumSelectionView
                    Spacer()
                    inputView
                        .padding(.bottom, g.safeAreaInsets.bottom)
                }
                .background(pickerTheme.main.pickerBackground)
                .ignoresSafeArea()
            } cameraSelectionBuilder: { _, cancelClosure, cameraSelectionView in
                VStack {
                    cameraSelectionHeaderView(cancelClosure: cancelClosure)
                        .padding(.top, g.safeAreaInsets.top)
                    cameraSelectionView
                    Spacer()
                    inputView
                        .padding(.bottom, g.safeAreaInsets.bottom)
                }
                .ignoresSafeArea()
            }
            .didPressCancelCamera {
                inputViewModel.showPicker = false
            }
            .currentFullscreenMedia($currentFullscreenMedia)
            .showLiveCameraCell()
            .setSelectionParameters(mediaPickerSelectionParameters)
            .pickerMode($mediaPickerMode)
            .orientationHandler(orientationHandler)
            .padding(.top)
            .background(pickerTheme.main.pickerBackground)
            .ignoresSafeArea(.all)
            .onChange(of: currentFullscreenMedia) { _, newValue in
                assembleSelectedMedia()
            }
            .onChange(of: inputViewModel.showPicker) {
                let showFullscreenPreview = mediaPickerSelectionParameters?.showFullscreenPreview ?? true
                let selectionLimit = mediaPickerSelectionParameters?.selectionLimit ?? 1

                if selectionLimit == 1 && !showFullscreenPreview {
                    assembleSelectedMedia()
                    inputViewModel.send()
                }
            }
        }
    }

    func assembleSelectedMedia() {
        if !seleсtedMedias.isEmpty {
            inputViewModel.attachments.medias = seleсtedMedias
        } else if let media = currentFullscreenMedia {
            inputViewModel.attachments.medias = [media]
        } else {
            inputViewModel.attachments.medias = []
        }
    }

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
            }
        }
    }

    var albumSelectionHeaderView: some View {
        ZStack {
            HStack {
                Button {
                    seleсtedMedias = []
                    inputViewModel.showPicker = false
                } label: {
                    Text("Скасувати") // localized "Cancel"
                        .foregroundColor(Color.primary.opacity(0.7))
                }

                Spacer()
            }

            HStack {
                Text("Останні") // localized "Recents"
                Image(systemName: "chevron.down")
                    .rotationEffect(Angle(radians: showingAlbums ? .pi : 0))
            }
            .foregroundColor(.primary)
            .onTapGesture {
                withAnimation {
                    inputViewModel.mediaPickerMode = showingAlbums ? .photos : .albums
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.bottom, 5)
    }

    func cameraSelectionHeaderView(cancelClosure: @escaping ()->()) -> some View {
        HStack {
            Button {
                cancelClosure()
            } label: {
                theme.images.mediaPicker.cross
            }
            .padding(.trailing, 30)

            if let chatTitle = chatTitle {
                theme.images.mediaPicker.chevronRight
                Text(chatTitle)
                    .font(.title3)
                    .foregroundColor(theme.colors.textMediaPicker)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
}
