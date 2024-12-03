//
//  ZoomGesture.swift
//  PhotoGallery
//
//  Created by Boris on 15.11.2023.
//

import SwiftUI

struct ZoomGesture: UIViewRepresentable {
    var size: CGSize
    @Binding var offset: CGPoint
    @Binding var scale: CGFloat
    @Binding var scalePosition: CGPoint
    
    func makeUIView(context: Context) -> some UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.onPinchGesture(_:))
        )
        view.addGestureRecognizer(pinch)
        
        let pan = UIPanGestureRecognizer(
            target: context.coordinator, 
            action: #selector(context.coordinator.onPanGesture(_:))
        )
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let parent: ZoomGesture
        
        init(parent: ZoomGesture) {
            self.parent = parent
        }
        
        // MARK: - Pinch
        @objc func onPinchGesture(_ sender: UIPinchGestureRecognizer) {
            switch sender.state {
            case .began, .changed:
                guard let view = sender.view else { return }
                parent.scale = sender.scale - 1
                let scalePosition = CGPoint(
                    x: sender.location(in: view).x / view.frame.width,
                    y: sender.location(in: view).y / view.frame.height)
                parent.scalePosition = parent.scalePosition == .zero ? scalePosition : parent.scalePosition
            default:
//                withAnimation(.easeInOut(duration: 0.1)) {
//                    parent.scale = -1
//                    parent.scalePosition = .zero
//                }
                parent.scale = -1
                parent.scalePosition = .zero
            }
        }
        
        // MARK: - Pan
        @objc func onPanGesture(_ sender: UIPanGestureRecognizer) {
            sender.maximumNumberOfTouches = 2
            switch sender.state {
            case .began, .changed:
                guard let view = sender.view, parent.scale > 0 else { return }
                let translation = sender.translation(in: view)
                parent.offset = translation
            default:
//                withAnimation(.easeInOut(duration: 0.1)) {
//                    parent.offset = .zero
//                    parent.scalePosition = .zero
//                }
                parent.offset = .zero
                parent.scalePosition = .zero
            }
        }
        
        // MARK: - UIGestureRecognizerDelegate
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
