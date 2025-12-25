//
//  ImagePreviewCell.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 09.11.2025.
//

import SwiftUI
import Photos
import UIKit

// MARK: - ImagePreviewCell

final class ImagePreviewCell: UICollectionViewCell {
    static let reuseId = "img"

    private var hosting: UIHostingController<ZoomingImageRoot>?
    private var zoomModel: ZoomingImageModel?

    private let spinner = UIActivityIndicatorView(style: .large)
    private var imageRequestID: PHImageRequestID?

    private lazy var doubleTapGR: UITapGestureRecognizer = {
        let gr = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        gr.numberOfTapsRequired = 2
        gr.cancelsTouchesInView = false
        return gr
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .black

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        contentView.addSubview(spinner)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])

        contentView.addGestureRecognizer(doubleTapGR)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        hosting?.view.frame = contentView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelImageRequest()
        spinner.startAnimating()
    }

    // MARK: - Public API

    func configurePlaceholder(thumb: UIImage?) {
        cancelImageRequest()
        spinner.startAnimating()

        let placeholder = thumb ?? UIImage()

        if let model = zoomModel {
            model.image = placeholder
            return
        }

        let model = ZoomingImageModel(image: placeholder)
        zoomModel = model

        let root = ZoomingImageRoot(model: model)
        let hc = UIHostingController(rootView: root)
        hc.view.backgroundColor = .clear
        hc.view.translatesAutoresizingMaskIntoConstraints = true
        hc.view.frame = contentView.bounds

        if let parentVC = findViewController() {
            parentVC.addChild(hc)
            contentView.insertSubview(hc.view, belowSubview: spinner)
            hc.didMove(toParent: parentVC)
        } else {
            contentView.insertSubview(hc.view, belowSubview: spinner)
        }

        hosting = hc
    }

    func requestFullImage(asset: PHAsset, targetSize: CGSize, manager: PHCachingImageManager) {
        let ts = CGSize(width: max(1, targetSize.width), height: max(1, targetSize.height))

        imageRequestID = manager.requestImage(
            for: asset,
            targetSize: ts,
            contentMode: .aspectFit,
            options: PreviewViewController.imageRequestOptions
        ) { [weak self] image, _ in
            guard let self else { return }
            if let image {
                self.zoomModel?.image = image
            }
            if self.zoomModel?.image != nil {
                self.spinner.stopAnimating()
            }
        }
    }

    func retryIfNeeded(asset: PHAsset, targetSize: CGSize, manager: PHCachingImageManager) {
        if zoomModel?.image == nil || spinner.isAnimating {
            requestFullImage(asset: asset, targetSize: targetSize, manager: manager)
        }
    }

    func cancelImageRequest() {
        if let id = imageRequestID {
            PHImageManager.default().cancelImageRequest(id)
            imageRequestID = nil
        }
    }

    // MARK: - Private

    @objc private func handleDoubleTap() {
        zoomModel?.doubleTap.toggle()
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}
