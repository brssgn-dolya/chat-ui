//
//  PreviewViewController.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 09.11.2025.
//

import UIKit
import AVKit
import Photos

// MARK: - Preview

final class PreviewViewController: UIViewController,
                                   UICollectionViewDataSource,
                                   UICollectionViewDelegate,
                                   UICollectionViewDataSourcePrefetching {

    private var collectionView: UICollectionView!

    private let items: [AssetItem]
    private var currentIndex: Int
    private let thumbProvider: (String) -> UIImage?

    private let requestPlayer: (PHAsset, @escaping (AVPlayer?) -> Void) -> PHImageRequestID?
    private let cancelRequest: (PHImageRequestID) -> Void

    private let isSelectedAt: (String) -> Bool
    private let toggleAt: (String) -> Bool
    private let selectedCount: () -> Int
    private let onSend: () async -> Void

    private var playerVCs: [Int: AVPlayerViewController] = [:]
    private var pendingReq: [Int: PHImageRequestID] = [:]

    private let imageManager: PHCachingImageManager = .init()

    private weak var checkButton: UIButton?
    private weak var sendButton: UIButton?

    private var isSending = false { didSet { updateBarsUI() } }
    private let send = UIButton(type: .system)

    // MARK: - Init

    init(
        items: [AssetItem],
        currentIndex: Int,
        thumbProvider: @escaping (String) -> UIImage?,
        requestPlayer: @escaping (PHAsset, @escaping (AVPlayer?) -> Void) -> PHImageRequestID?,
        cancelRequest: @escaping (PHImageRequestID) -> Void,
        isSelectedAt: @escaping (String) -> Bool,
        toggleAt: @escaping (String) -> Bool,
        selectedCount: @escaping () -> Int,
        onSend: @escaping () async -> Void
    ) {
        self.items = items
        self.currentIndex = currentIndex
        self.thumbProvider = thumbProvider
        self.requestPlayer = requestPlayer
        self.cancelRequest = cancelRequest
        self.isSelectedAt = isSelectedAt
        self.toggleAt = toggleAt
        self.selectedCount = selectedCount
        self.onSend = onSend
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isPagingEnabled = true
        collectionView.backgroundColor = .systemBackground
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(ImagePreviewCell.self, forCellWithReuseIdentifier: ImagePreviewCell.reuseId)
        collectionView.register(VideoHostCell.self, forCellWithReuseIdentifier: VideoHostCell.reuseId)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.prefetchDataSource = self

        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -84),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let top = UIView()
        top.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        top.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(top)

        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            top.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            top.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        func makeNavIconButton(systemName: String, target: Any?, action: Selector?) -> UIButton {
            let b = UIButton(type: .system)
            b.translatesAutoresizingMaskIntoConstraints = false
            let sym = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular, scale: .large)
            b.setPreferredSymbolConfiguration(sym, forImageIn: .normal)
            b.setImage(UIImage(systemName: systemName), for: .normal)
            b.tintColor = .label
            b.imageView?.contentMode = .center
            b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            b.contentHorizontalAlignment = .center
            b.contentVerticalAlignment = .center
            if let action { b.addTarget(target, action: action, for: .touchUpInside) }
            return b
        }

        let close = makeNavIconButton(systemName: "xmark", target: self, action: #selector(dismissSelf))

        let check = makeNavIconButton(systemName: "checkmark", target: nil, action: nil)
        check.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let id = self.items[self.currentIndex].localID
            let changed = self.toggleAt(id)
            if !changed {
                self.showSelectionLimitAlert(limit: 10)
            }
            self.updateBarsUI()
        }, for: .touchUpInside)
        self.checkButton = check

        let topStack = UIStackView(arrangedSubviews: [close, UIView(), check])
        topStack.axis = .horizontal
        topStack.alignment = .center
        topStack.translatesAutoresizingMaskIntoConstraints = false
        top.addSubview(topStack)

        NSLayoutConstraint.activate([
            topStack.leadingAnchor.constraint(equalTo: top.leadingAnchor, constant: 8),
            topStack.trailingAnchor.constraint(equalTo: top.trailingAnchor, constant: -8),
            topStack.topAnchor.constraint(equalTo: top.topAnchor, constant: 8),
            topStack.bottomAnchor.constraint(equalTo: top.bottomAnchor, constant: -8),
        ])

        collectionView.topAnchor.constraint(equalTo: top.bottomAnchor).isActive = true

        let bottom = UIView()
        bottom.backgroundColor = .clear
        bottom.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottom)

        NSLayoutConstraint.activate([
            bottom.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottom.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottom.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottom.heightAnchor.constraint(equalToConstant: 96)
        ])

        collectionView.bottomAnchor.constraint(equalTo: bottom.topAnchor).isActive = true

        SendButtonStyle.apply(to: send, state: .init(selectedCount: selectedCount(), sending: false))
        send.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.isSending = true
            self.updateBarsUI()
            Task { [weak self] in
                guard let self else { return }
                await self.onSend()
            }
        }, for: .touchUpInside)
        self.sendButton = send

        let bottomStack = UIStackView(arrangedSubviews: [send])
        bottomStack.axis = .horizontal
        bottomStack.alignment = .center
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottom.addSubview(bottomStack)

        NSLayoutConstraint.activate([
            bottomStack.centerXAnchor.constraint(equalTo: bottom.centerXAnchor),
            bottomStack.centerYAnchor.constraint(equalTo: bottom.safeAreaLayoutGuide.centerYAnchor),
            send.widthAnchor.constraint(lessThanOrEqualTo: bottom.widthAnchor, constant: -48),
            send.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = collectionView.bounds.size
            layout.invalidateLayout()
        }

        if items.isEmpty { return }
        if currentIndex < 0 { currentIndex = 0 }
        if currentIndex >= items.count { currentIndex = items.count - 1 }

        if collectionView.indexPathsForVisibleItems.isEmpty {
            let indexPath = IndexPath(item: currentIndex, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
        }

        preheatAround(index: currentIndex)
        updateBarsUI()
    }

    // MARK: - Data Source / Delegate

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let it = items[indexPath.item]
        if it.mediaType == .video {
            let cell = cv.dequeueReusableCell(withReuseIdentifier: VideoHostCell.reuseId, for: indexPath) as! VideoHostCell
            cell.spinner.startAnimating()
            return cell
        } else {
            let cell = cv.dequeueReusableCell(withReuseIdentifier: ImagePreviewCell.reuseId, for: indexPath) as! ImagePreviewCell
            let thumb = thumbProvider(it.localID)
            cell.configurePlaceholder(thumb: thumb)
            let targetSize = CGSize(
                width: max(1, cell.bounds.width) * UIScreen.main.scale,
                height: max(1, cell.bounds.height) * UIScreen.main.scale
            )
            cell.requestFullImage(asset: it.asset, targetSize: targetSize, manager: imageManager)
            return cell
        }
    }

    func collectionView(_ cv: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]

        if item.mediaType == .video, let vcell = cell as? VideoHostCell {
            if let pvc = playerVCs[indexPath.item] {
                attach(pvc, to: vcell)
                pvc.player?.play()
                vcell.spinner.stopAnimating()
                return
            }

            if let rid = pendingReq[indexPath.item] {
                cancelRequest(rid)
                pendingReq[indexPath.item] = nil
            }

            if let reqID = requestPlayer(item.asset, { [weak self, weak vcell] player in
                guard let self, let vcell else { return }
                guard cv.indexPath(for: vcell) == indexPath else {
                    self.pendingReq[indexPath.item] = nil
                    return
                }
                self.pendingReq[indexPath.item] = nil
                guard let player else {
                    vcell.spinner.stopAnimating()
                    return
                }
                let pvc = AVPlayerViewController()
                pvc.player = player
                pvc.showsPlaybackControls = true
                pvc.allowsPictureInPicturePlayback = true
                self.playerVCs[indexPath.item] = pvc
                self.attach(pvc, to: vcell)
                vcell.spinner.stopAnimating()
                player.play()
            }) {
                pendingReq[indexPath.item] = reqID
            }
        } else if let icell = cell as? ImagePreviewCell {
            let targetSize = CGSize(
                width: max(1, icell.bounds.width) * UIScreen.main.scale,
                height: max(1, icell.bounds.height) * UIScreen.main.scale
            )
            icell.retryIfNeeded(asset: item.asset, targetSize: targetSize, manager: imageManager)
        }
    }

    private func attach(_ pvc: AVPlayerViewController, to cell: VideoHostCell) {
        pvc.willMove(toParent: nil)
        pvc.view.removeFromSuperview()
        pvc.removeFromParent()

        addChild(pvc)
        cell.container.addSubview(pvc.view)
        pvc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pvc.view.topAnchor.constraint(equalTo: cell.container.topAnchor),
            pvc.view.bottomAnchor.constraint(equalTo: cell.container.bottomAnchor),
            pvc.view.leadingAnchor.constraint(equalTo: cell.container.leadingAnchor),
            pvc.view.trailingAnchor.constraint(equalTo: cell.container.trailingAnchor),
        ])
        pvc.didMove(toParent: self)
    }

    func collectionView(_ cv: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let pvc = playerVCs[indexPath.item] {
            pvc.player?.pause()
            pvc.willMove(toParent: nil)
            pvc.view.removeFromSuperview()
            pvc.removeFromParent()
            playerVCs.removeValue(forKey: indexPath.item)
        }
        if let rid = pendingReq[indexPath.item] {
            cancelRequest(rid)
            pendingReq[indexPath.item] = nil
        }
        (cell as? ImagePreviewCell)?.cancelImageRequest()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.x / max(1, scrollView.bounds.width))
        currentIndex = max(0, min(items.count - 1, page))
        preheatAround(index: currentIndex)
        updateBarsUI()
    }

    @objc private func dismissSelf() { dismiss(animated: true) }

    // MARK: - Prefetching

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let assets = indexPaths.compactMap { idx -> PHAsset? in
            guard idx.item < items.count else { return nil }
            return items[idx.item].mediaType == .video ? nil : items[idx.item].asset
        }
        guard !assets.isEmpty else { return }

        imageManager.startCachingImages(
            for: assets,
            targetSize: prefetchTargetSize(),
            contentMode: .aspectFit,
            options: Self.imageRequestOptions
        )
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let assets = indexPaths.compactMap { idx -> PHAsset? in
            guard idx.item < items.count else { return nil }
            return items[idx.item].mediaType == .video ? nil : items[idx.item].asset
        }
        guard !assets.isEmpty else { return }

        imageManager.stopCachingImages(
            for: assets,
            targetSize: prefetchTargetSize(),
            contentMode: .aspectFit,
            options: Self.imageRequestOptions
        )
    }

    private func prefetchTargetSize() -> CGSize {
        let size = collectionView.bounds.size
        return CGSize(
            width: max(1, size.width) * UIScreen.main.scale,
            height: max(1, size.height) * UIScreen.main.scale
        )
    }

    private func preheatAround(index: Int) {
        let neighbors = [-2, -1, 1, 2].map { index + $0 }.filter { $0 >= 0 && $0 < items.count }
        let assets = neighbors.compactMap { i -> PHAsset? in
            items[i].mediaType == .video ? nil : items[i].asset
        }
        guard !assets.isEmpty else { return }

        imageManager.startCachingImages(
            for: assets,
            targetSize: prefetchTargetSize(),
            contentMode: .aspectFit,
            options: Self.imageRequestOptions
        )
    }

    // MARK: - Bars UI

    private func updateBarsUI() {
        if let check = checkButton, !items.isEmpty {
            let id = items[currentIndex].localID
            let selected = isSelectedAt(id)
            let name = selected ? "checkmark.circle.fill" : "circle"
            check.setImage(UIImage(systemName: name), for: .normal)
            check.isEnabled = !isSending
        }

        if let send = sendButton {
            let s = SendButtonStyle.State(selectedCount: selectedCount(), sending: isSending)
            SendButtonStyle.apply(to: send, state: s)
        }
    }

    // MARK: - Image Request Options

    static let imageRequestOptions: PHImageRequestOptions = {
        let o = PHImageRequestOptions()
        o.deliveryMode = .opportunistic
        o.resizeMode = .fast
        o.isNetworkAccessAllowed = true
        return o
    }()
}

extension UIViewController {
    func showSelectionLimitAlert(limit: Int) {
        let alert = UIAlertController(
            title: "Ліміт вибору",
            message: "Максимальна кількість елементів — \(limit).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
