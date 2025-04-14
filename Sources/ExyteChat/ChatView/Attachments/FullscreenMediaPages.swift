//
//  Created by Alex.M on 22.06.2022.
//

import Foundation
import SwiftUI

struct FullscreenMediaPages: View {

    @Environment(\.chatTheme) private var theme
    @Environment(\.mediaPickerTheme) var pickerTheme

    @StateObject var viewModel: FullscreenMediaPagesViewModel
    var safeAreaInsets: EdgeInsets
    var onClose: () -> Void
    var onSave: (Int) -> Void

    var body: some View {
        // Drag gesture for closing the fullscreen viewer
        let closeGesture = DragGesture()
            .onChanged { viewModel.offset = closeSize(from: $0.translation) }
            .onEnded {
                withAnimation {
                    viewModel.offset = .zero
                }
                if $0.translation.height >= 100 {
                    onClose()
                }
            }

        ZStack {
            // Background dimming based on drag offset
            Color.black
                .opacity(max((200.0 - viewModel.offset.height) / 200.0, 0.5))

            // Main fullscreen content
            VStack {
                TabView(selection: $viewModel.index) {
                    ForEach(viewModel.attachments.enumerated().map({ $0 }), id: \.offset) { (index, attachment) in
                        AttachmentsPage(attachment: attachment)
                            .tag(index)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                            .ignoresSafeArea()
                            .addPinchZoom()
                    }
                }
                .environmentObject(viewModel)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .offset(viewModel.offset)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { gesture in
                        guard abs(gesture.translation.height) > abs(gesture.translation.width) else { return }
                        viewModel.offset = closeSize(from: gesture.translation)
                    }
                    .onEnded { gesture in
                        if gesture.translation.height > 100 {
                            onClose()
                        } else {
                            withAnimation(.spring()) {
                                viewModel.offset = .zero
                            }
                        }
                    }
            )
            .onTapGesture {
                withAnimation {
                    viewModel.showMinis.toggle()
                }
            }

            // Bottom thumbnails view
            VStack {
                Spacer()
                ScrollViewReader { proxy in
                    if viewModel.showMinis {
                        ScrollView(.horizontal) {
                            HStack(spacing: 2) {
                                ForEach(viewModel.attachments.enumerated().map({ $0 }), id: \.offset) { (index, attachment) in
                                    AttachmentCell(attachment: attachment) { _ in
                                        withAnimation {
                                            viewModel.index = index
                                        }
                                    }
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(4)
                                    .clipped()
                                    .id(index)
                                    .overlay {
                                        if viewModel.index == index {
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(theme.colors.sendButtonBackground, lineWidth: 2)
                                        }
                                    }
                                    .padding(.vertical, 1)
                                }
                            }
                        }
                        .padding([.top, .horizontal], 12)
                        .background(Color.black)
                        .onAppear {
                            proxy.scrollTo(viewModel.index)
                        }
                        .onChange(of: viewModel.index) { newValue in
                            withAnimation {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                }
                .offset(y: -safeAreaInsets.bottom)
            }
            .offset(viewModel.offset)
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            if viewModel.showMinis {
                ZStack {
                    // Top blurred background with shadow
                    Color.black.opacity(0.4)
                        .frame(height: 40 + safeAreaInsets.top)
                        .edgesIgnoringSafeArea(.top)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                    HStack {
                        // Close button
                        Button(action: onClose) {
                            theme.images.mediaPicker.cross
                                .padding(5)
                        }
                        .tint(.white)
                        .padding(.leading, 15)

                        Spacer()

                        // Current page indicator
                        Text("\(viewModel.index + 1)/\(viewModel.attachments.count)")
                            .foregroundColor(.white)

                        Spacer()

                        // Right side action buttons
                        HStack(spacing: 20) {
                            if viewModel.attachments[viewModel.index].type == .video {
                                (viewModel.videoPlaying ? theme.images.fullscreenMedia.pause : theme.images.fullscreenMedia.play)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .padding(5)
                                    .foregroundColor(.white)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.toggleVideoPlaying()
                                    }

                                (viewModel.videoMuted ? theme.images.fullscreenMedia.mute : theme.images.fullscreenMedia.unmute)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .padding(5)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.toggleVideoMuted()
                                    }
                            }

                            theme.images.messageMenu.save
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .padding(5)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSave(viewModel.index)
                                }
                        }
                        .padding(.trailing, 10)
                    }
                    .padding(.top, safeAreaInsets.top)
                    .frame(height: 60)
                }
            }
        }
    }
}

private extension FullscreenMediaPages {
    // Helper to calculate vertical drag offset
    func closeSize(from size: CGSize) -> CGSize {
        CGSize(width: 0, height: max(size.height, 0))
    }
}
