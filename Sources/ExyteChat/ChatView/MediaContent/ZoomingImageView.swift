//
//  ZoomingImageView.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 09.11.2025.
//


import SwiftUI

// MARK: - ZoomingImageView
private struct ZoomingImageView: UIViewRepresentable {
    let image: UIImage
    @Binding var doubleTapTrigger: Bool

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 1.0
        scroll.maximumZoomScale = 4.0
        scroll.zoomScale = 1.0
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.bounces = true
        scroll.bouncesZoom = true
        scroll.decelerationRate = .fast
        scroll.isDirectionalLockEnabled = true
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.backgroundColor = .clear
        scroll.delegate = context.coordinator
        scroll.pinchGestureRecognizer?.isEnabled = false
        scroll.isScrollEnabled = false
        scroll.alwaysBounceHorizontal = false
        scroll.alwaysBounceVertical = false

        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.frame = scroll.bounds
        iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.addSubview(iv)

        context.coordinator.imageView = iv
        scroll.contentSize = iv.bounds.size
        context.coordinator.centerContents(in: scroll)
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        if let iv = context.coordinator.imageView as? UIImageView {
            if iv.image !== image {
                iv.image = image
                if scroll.zoomScale != 1.0 {
                    scroll.setZoomScale(1.0, animated: false)
                }
                context.coordinator.centerContents(in: scroll)
                context.coordinator.updateScrollEnabled(for: scroll.zoomScale, scroll: scroll)
            }
        }

        if context.coordinator.lastDoubleTapToken != doubleTapTrigger {
            context.coordinator.lastDoubleTapToken = doubleTapTrigger
            let target = (scroll.zoomScale > 1.01)
                ? 1.0
                : min(2.0, scroll.maximumZoomScale)
            UIView.animate(withDuration: 0.25) {
                scroll.setZoomScale(target, animated: false)
            }
            context.coordinator.centerContents(in: scroll)
            context.coordinator.updateScrollEnabled(for: scroll.zoomScale, scroll: scroll)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIView?
        var lastDoubleTapToken = false

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContents(in: scrollView)
            updateScrollEnabled(for: scrollView.zoomScale, scroll: scrollView)
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            if scale <= 1.01, scrollView.zoomScale != 1.0 {
                scrollView.setZoomScale(1.0, animated: false)
                centerContents(in: scrollView)
            }
            updateScrollEnabled(for: scrollView.zoomScale, scroll: scrollView)
        }

        func updateScrollEnabled(for zoom: CGFloat, scroll: UIScrollView) {
            let enable = zoom > 1.01
            scroll.isScrollEnabled = enable
            scroll.alwaysBounceHorizontal = enable
            scroll.alwaysBounceVertical = enable
        }

        func centerContents(in scrollView: UIScrollView) {
            guard let v = imageView else { return }
            let boundsSize = scrollView.bounds.size
            let contentSize = v.frame.size
            let horizontalInset = max(0, (boundsSize.width - contentSize.width) * 0.5)
            let verticalInset   = max(0, (boundsSize.height - contentSize.height) * 0.5)
            scrollView.contentInset = UIEdgeInsets(top: verticalInset,
                                                   left: horizontalInset,
                                                   bottom: verticalInset,
                                                   right: horizontalInset)
        }
    }
}

// MARK: - SwiftUI host root
final class ZoomingImageModel: ObservableObject {
    @Published var image: UIImage
    @Published var doubleTap: Bool = false
    init(image: UIImage) { self.image = image }
}

struct ZoomingImageRoot: View {
    @ObservedObject var model: ZoomingImageModel
    var body: some View {
        ZoomingImageView(image: model.image, doubleTapTrigger: $model.doubleTap)
            .background(Color.clear)
    }
}
