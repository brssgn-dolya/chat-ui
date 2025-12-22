
import SwiftUI
import Photos
import AVFoundation
import AVKit
import UIKit

// MARK: - Public Models

public struct PickerResult: Hashable {
    public enum Kind: Hashable { case image(data: Data), video(url: URL) }
    public let kind: Kind
}

// MARK: - SwiftUI facade

public struct CustomPhotoPicker: View {
    public enum MediaFilter { case images, videos, any }

    @Binding var isPresented: Bool
    let selectionLimit: Int
    let mediaFilter: MediaFilter
    let onComplete: ([PickerResult]) -> Void

    @State private var isSending = false

    public init(
        isPresented: Binding<Bool>,
        selectionLimit: Int,
        mediaFilter: MediaFilter,
        onComplete: @escaping ([PickerResult]) -> Void
    ) {
        self._isPresented = isPresented
        self.selectionLimit = selectionLimit
        self.mediaFilter = mediaFilter
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            PhotoPickerHost(
                isPresented: $isPresented,
                selectionLimit: selectionLimit,
                mediaFilter: mediaFilter,
                onComplete: onComplete,
                isSending: $isSending
            )
            if isSending { Color.black.opacity(0.05).ignoresSafeArea() }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}

// MARK: - SwiftUI host

struct PhotoPickerHost: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let selectionLimit: Int
    let mediaFilter: CustomPhotoPicker.MediaFilter
    let onComplete: ([PickerResult]) -> Void
    @Binding var isSending: Bool

    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = GridViewController(
            selectionLimit: selectionLimit,
            mediaFilter: mediaFilter,
            onCancel: { isPresented = false },
            onRequestLimitedMore: { GridViewController.presentLimitedLibraryPicker() },
            onSend: { results in
                onComplete(results)
                isPresented = false
            },
            setIsSending: { isSending = $0 }
        )
        let nav = UINavigationController(rootViewController: vc)
        nav.isNavigationBarHidden = true
        nav.modalPresentationStyle = .overFullScreen
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

// MARK: - Internal models

struct AssetItem: Hashable {
    let localID: String
    let asset: PHAsset
    var mediaType: PHAssetMediaType { asset.mediaType }
}

enum Section: Hashable { case main }

struct OrderedSet<Element: Hashable>: RandomAccessCollection, MutableCollection {
    private var array: [Element] = []
    private var set: Set<Element> = []

    var startIndex: Int { array.startIndex }
    var endIndex: Int { array.endIndex }
    subscript(position: Int) -> Element { get { array[position] } set { fatalError() } }

    mutating func append(_ new: Element) {
        if set.insert(new).inserted { array.append(new) }
    }
    mutating func remove(at i: Int) {
        set.remove(array[i]); array.remove(at: i)
    }
    func firstIndex(of e: Element) -> Int? { array.firstIndex(of: e) }
    func contains(_ e: Element) -> Bool { set.contains(e) }
}
