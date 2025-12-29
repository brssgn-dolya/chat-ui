//
//  GridViewController.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 09.11.2025.
//

import UIKit
import Photos
import SwiftUI

// MARK: - GridViewController

final class GridViewController: UIViewController {

    // MARK: - Properties

    private let selectionLimit: Int
    private let mediaFilter: CustomPhotoPicker.MediaFilter
    private var auth: PHAuthorizationStatus = .notDetermined

    private var allAssets: PHFetchResult<PHAsset> = .init()
    private var items: [AssetItem] = []
    private var selectedIDs = OrderedSet<String>()

    private let caching = PHCachingImageManager()
    private let thumbCache = NSCache<NSString, UIImage>()
    private var previousPreheatRect: CGRect = .zero

    private var pendingThumb: [String: PHImageRequestID] = [:]
    private var isSending = false

    // MARK: - UI

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, AssetItem>!
    private var permissionHost: UIHostingController<GalleryPermissionView>?
    
    private let sendButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    
    // MARK: - Callbacks

    private let onCancel: () -> Void
    private let onRequestLimitedMore: () -> Void
    private let onSend: ([PickerResult]) -> Void
    private let setIsSending: (Bool) -> Void

    // MARK: - Layout Metrics
    
    private let topLeftGuide  = UILayoutGuide()
    private let topRightGuide = UILayoutGuide()

    private var thumbnailPixelSize: CGSize = CGSize(width: 600, height: 600)
    private let emptyStateView = LimitedGalleryEmptyStateView()

    // MARK: - Init / Deinit

    init(
        selectionLimit: Int,
        mediaFilter: CustomPhotoPicker.MediaFilter,
        onCancel: @escaping () -> Void,
        onRequestLimitedMore: @escaping () -> Void,
        onSend: @escaping ([PickerResult]) -> Void,
        setIsSending: @escaping (Bool) -> Void
    ) {
        self.selectionLimit = selectionLimit
        self.mediaFilter = mediaFilter
        self.onCancel = onCancel
        self.onRequestLimitedMore = onRequestLimitedMore
        self.onSend = onSend
        self.setIsSending = setIsSending
        super.init(nibName: nil, bundle: nil)
        PHPhotoLibrary.shared().register(self)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        thumbCache.totalCostLimit = 50 * 1024 * 1024
        configureCollectionView()
        configureDataSource()
        configureBars()
        
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        emptyStateView.onPickMore = { [weak self] in
            guard let self else { return }
            self.presentLimitedPicker(from: self)
        }

        emptyStateView.onClose = { [weak self] in
            self?.onCancel()
        }

        Task { await requestAuthAndLoadIfNeeded() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCachedAssets()
        recalcThumbnailSizeIfNeeded()
    }

    private func updateLimitedEmptyStateUI() {
        if auth == .limited, !selectedIDs.isEmpty {
            let allowed = Set(items.map(\.localID))
            let filtered = selectedIDs.filter { allowed.contains($0) }

            if filtered.count != selectedIDs.count {
                var newSet = OrderedSet<String>()
                for id in filtered {
                    newSet.append(id)
                }
                selectedIDs = newSet
                updateSendButtonState()
            }
        }

        let shouldShow = (auth == .limited) && items.isEmpty

        emptyStateView.isHidden = !shouldShow
        collectionView.isHidden = shouldShow
        sendButton.isHidden = shouldShow

        if shouldShow, !selectedIDs.isEmpty {
            selectedIDs = OrderedSet()
            updateSendButtonState()
        }
    }

    // MARK: - UI Setup

    private func configureCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let spacing: CGFloat = 1
            let columns = 3
            let fraction = 1.0 / CGFloat(columns)

            let item = NSCollectionLayoutItem(
                layoutSize: .init(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(1.0)
                )
            )

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalWidth(fraction)
                ),
                subitem: item,
                count: columns
            )
            group.interItemSpacing = .fixed(spacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsets = .init(top: spacing, leading: 0, bottom: 0, trailing: 0)
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.register(AssetCell.self, forCellWithReuseIdentifier: AssetCell.reuseID)

        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -84),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Top/Bottom Bars

    private func configureBars() {
        let top = UIView()
        top.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        top.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(top)

        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: view.topAnchor),
            top.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            top.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            top.heightAnchor.constraint(equalToConstant: 56)
        ])

        top.addLayoutGuide(topLeftGuide)
        top.addLayoutGuide(topRightGuide)

        NSLayoutConstraint.activate([
            topLeftGuide.leadingAnchor.constraint(equalTo: top.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            topLeftGuide.centerYAnchor.constraint(equalTo: top.safeAreaLayoutGuide.centerYAnchor),
            topLeftGuide.heightAnchor.constraint(equalToConstant: 44),

            topRightGuide.trailingAnchor.constraint(equalTo: top.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            topRightGuide.centerYAnchor.constraint(equalTo: top.safeAreaLayoutGuide.centerYAnchor),
            topRightGuide.heightAnchor.constraint(equalToConstant: 44),

            topLeftGuide.widthAnchor.constraint(equalTo: topRightGuide.widthAnchor)
        ])

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .label
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        top.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: topLeftGuide.leadingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: topLeftGuide.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        moreButton.translatesAutoresizingMaskIntoConstraints = false
        moreButton.setTitle("Обрати більше", for: .normal)
        moreButton.addTarget(self, action: #selector(didTapMore), for: .touchUpInside)
        moreButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        moreButton.titleLabel?.numberOfLines = 1
        moreButton.titleLabel?.lineBreakMode = .byTruncatingTail
        moreButton.titleLabel?.adjustsFontForContentSizeCategory = true
        moreButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        moreButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        moreButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        top.addSubview(moreButton)

        NSLayoutConstraint.activate([
            moreButton.trailingAnchor.constraint(equalTo: topRightGuide.trailingAnchor),
            moreButton.leadingAnchor.constraint(greaterThanOrEqualTo: topRightGuide.leadingAnchor),
            moreButton.centerYAnchor.constraint(equalTo: topRightGuide.centerYAnchor),
            moreButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Галерея"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        top.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: top.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: top.safeAreaLayoutGuide.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: topLeftGuide.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: topRightGuide.leadingAnchor, constant: -8)
        ])

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

        sendButton.configuration = .dolyaSend(selectedCount: 0, sending: false, sendButton: sendButton)
        sendButton.isEnabled = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        bottom.addSubview(sendButton)

        NSLayoutConstraint.activate([
            sendButton.centerXAnchor.constraint(equalTo: bottom.safeAreaLayoutGuide.centerXAnchor),
            sendButton.centerYAnchor.constraint(equalTo: bottom.safeAreaLayoutGuide.centerYAnchor),
            sendButton.leadingAnchor.constraint(greaterThanOrEqualTo: bottom.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            sendButton.trailingAnchor.constraint(lessThanOrEqualTo: bottom.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            sendButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    // MARK: - Diffable Data Source

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, AssetItem>(collectionView: collectionView) { [weak self] cv, indexPath, item in
            guard let self,
                  let cell = cv.dequeueReusableCell(withReuseIdentifier: AssetCell.reuseID, for: indexPath) as? AssetCell
            else { return UICollectionViewCell() }

            cell.representedAssetIdentifier = item.localID

            let cached = self.thumbCache.object(forKey: item.localID as NSString)
            cell.configure(
                with: cached,
                isVideo: item.mediaType == .video,
                duration: item.asset.duration,
                isSelected: self.selectedIDs.contains(item.localID)
            )

            if cached == nil {
                if let prev = self.pendingThumb[item.localID] {
                    self.caching.cancelImageRequest(prev)
                    self.pendingThumb.removeValue(forKey: item.localID)
                }
                
                let reqID = self.requestThumb(for: item, targetSize: self.thumbnailPixelSize) { [weak self, weak cell] image, isDegraded in
                    guard let self,
                          let cell,
                          cell.representedAssetIdentifier == item.localID else { return }

                    if let image {
                        if !isDegraded {
                            self.thumbCache.setObject(
                                image,
                                forKey: item.localID as NSString,
                                cost: Int(image.size.width * image.size.height)
                            )
                        }
                        cell.configure(
                            with: image,
                            isVideo: item.mediaType == .video,
                            duration: item.asset.duration,
                            isSelected: self.selectedIDs.contains(item.localID)
                        )
                    }
                }
                self.pendingThumb[item.localID] = reqID
            }

            cell.onToggle = { [weak self] id in
                _ = self?.toggleSelect(withID: id)
            }

            cell.onPeek = { [weak self] in
                guard let self else { return }
                guard let idx = self.items.firstIndex(where: { $0.localID == item.localID }) else { return }
                self.openPreview(startingAt: idx)
            }

            return cell
        }
    }

    // MARK: - Layout Helpers

    private func recalcThumbnailSizeIfNeeded() {
        let columns: CGFloat = 3
        let spacing: CGFloat = 1
        let totalSpacing = (columns - 1) * spacing
        let w = max(2, (collectionView.bounds.width - totalSpacing) / columns)
        let scale = UIScreen.main.scale
        let px = floor(w * scale)
        let newSize = CGSize(width: px, height: px)
        if thumbnailPixelSize != newSize {
            thumbnailPixelSize = newSize
        }
    }

    // MARK: - Fetching / Predicates

    private func predicate(for filter: CustomPhotoPicker.MediaFilter) -> NSPredicate? {
        switch filter {
        case .images: return NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        case .videos: return NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        case .any:    return nil
        }
    }

    private func fetchAssets() {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if let p = predicate(for: mediaFilter) { opts.predicate = p }
        allAssets = PHAsset.fetchAssets(with: opts)

        items = (0..<allAssets.count).map {
            let a = allAssets.object(at: $0)
            return AssetItem(localID: a.localIdentifier, asset: a)
        }

        thumbCache.removeAllObjects()
        pendingThumb.removeAll()

        applySnapshot()
        updateCachedAssets()
        updateLimitedButtonVisibility()
        updateLimitedEmptyStateUI()
    }

    // MARK: - Snapshot

    private func applySnapshot(anim: Bool = true) {
        var snap = NSDiffableDataSourceSnapshot<Section, AssetItem>()
        snap.appendSections([.main])
        snap.appendItems(items)
        dataSource.apply(snap, animatingDifferences: anim)
    }

    // MARK: - UI State

    private func updateLimitedButtonVisibility() {
        moreButton.isHidden = (auth != .limited)
    }

    // MARK: - Permissions

    @MainActor
    private func requestAuthAndLoadIfNeeded() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
        case .authorized, .limited:
            auth = current
            fetchAssets()
        case .denied, .restricted:
            auth = current
            showPermissionView()
        case .notDetermined:
            let s = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            auth = s
            if s == .authorized || s == .limited { fetchAssets() }
            else { showPermissionView() }
        @unknown default:
            auth = .denied
            showPermissionView()
        }
    }

    // MARK: - Permission View (SwiftUI Hosting)

    private func showPermissionView() {
        guard permissionHost == nil else { return }

        let swiftUIView = GalleryPermissionView(
            title: "Доступ до Фото",
            subtitle: "Дозвольте доступ до Фото, щоб обрати медіа для відправки.",
            onOpenSettings: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            },
            onNotNow: { },
            onClose: { [weak self] in
                guard let self else { return }
                self.dismissPermissionView()
                self.onCancel()
            }
        )

        let host = UIHostingController(rootView: swiftUIView)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear

        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)

        permissionHost = host

        host.view.alpha = 0
        UIView.animate(withDuration: 0.2) { host.view.alpha = 1 }
    }

    private func dismissPermissionView() {
        guard let host = permissionHost else { return }
        permissionHost = nil

        host.willMove(toParent: nil)
        UIView.animate(withDuration: 0.2, animations: {
            host.view.alpha = 0
        }, completion: { _ in
            host.view.removeFromSuperview()
            host.removeFromParent()
        })
    }

    // MARK: - Selection

    @discardableResult
    private func toggleSelect(withID id: String) -> Bool {
        if let idx = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: idx)
        } else {
            let limit = 10
            guard selectedIDs.count < limit else {
                showSelectionLimitAlert(limit: limit)
                return false
            }
            selectedIDs.append(id)
        }

        updateSendButtonState()

        guard let item = items.first(where: { $0.localID == id }) else { return true }
        var snap = dataSource.snapshot()
        if snap.indexOfItem(item) != nil {
            snap.reconfigureItems([item])
            dataSource.apply(snap, animatingDifferences: false)
        }

        return true
    }

    private func updateSendButtonState() {
        let s = SendButtonStyle.State(selectedCount: selectedIDs.count, sending: isSending)
        SendButtonStyle.apply(to: sendButton, state: s)
    }

    // MARK: - Preview

    @MainActor
    private func openPreview(startingAt index: Int) {
        let preview = PreviewViewController(
            items: items,
            currentIndex: index,
            thumbProvider: { [weak self] id in
                self?.thumbCache.object(forKey: id as NSString)
            },
            requestPlayer: { [weak self] asset, completion in
                guard let self else { return nil }
                let opts = PHVideoRequestOptions()
                opts.isNetworkAccessAllowed = true
                opts.deliveryMode = .automatic
                opts.version = .original
                let reqID = self.caching.requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
                    DispatchQueue.main.async {
                        if let avAsset {
                            completion(AVPlayer(playerItem: AVPlayerItem(asset: avAsset)))
                        } else {
                            completion(nil)
                        }
                    }
                }
                return reqID
            },
            cancelRequest: { [weak self] requestID in
                self?.caching.cancelImageRequest(requestID)
            },
            isSelectedAt: { [weak self] id in
                self?.selectedIDs.contains(id) ?? false
            },
            toggleAt: { [weak self] id in
                self?.toggleSelect(withID: id) ?? false
            },
            selectedCount: { [weak self] in
                self?.selectedIDs.count ?? 0
            },
            onSend: { [weak self] in
                guard let self else { return }
                await self.exportAndSend()
            }
        )
        present(preview, animated: true)
    }

    // MARK: - Actions

    @objc private func didTapSend() { exportAndSend() }
    @objc private func didTapClose() { onCancel() }

    @objc private func didTapMore() {
        guard auth == .limited else {
            let alert = UIAlertController(
                title: "Доступ до Фото",
                message: "Ця дія доступна лише коли ви надали обмежений доступ до Фото. Відкрийте Налаштування, щоб змінити доступ.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Відмінити", style: .cancel))
            alert.addAction(UIAlertAction(title: "Відкрити Налаштування", style: .default, handler: { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }))
            present(alert, animated: true)
            return
        }
        presentLimitedPicker(from: self)
    }

    // MARK: - Limited Access Picker

    private func presentLimitedPicker(from presenter: UIViewController) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter)
        } else {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }
    }

    static func presentLimitedLibraryPicker() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: root)
    }

    // MARK: - Thumbnails

    @discardableResult
    private func requestThumb(
        for item: AssetItem,
        targetSize: CGSize,
        completion: @escaping (UIImage?, Bool) -> Void
    ) -> PHImageRequestID {
        let opts = PHImageRequestOptions()
        opts.isSynchronous = false
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .opportunistic
        opts.resizeMode = .fast

        return caching.requestImage(
            for: item.asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: opts
        ) { img, info in
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            if cancelled { return }
            completion(img, degraded)
        }
    }

    // MARK: - Sending

    private func setSendingUI(_ sending: Bool) {
        isSending = sending
        setIsSending(sending)
        let s = SendButtonStyle.State(selectedCount: selectedIDs.count, sending: sending)
        SendButtonStyle.apply(to: sendButton, state: s)
    }

    private func exportAndSend() {
        guard !selectedIDs.isEmpty, !isSending else { return }
        setSendingUI(true)

        let map = Dictionary(uniqueKeysWithValues: items.map { ($0.localID, $0.asset) })
        let ordered = selectedIDs.compactMap { map[$0] }

        DispatchQueue.global(qos: .utility).async {
            let results = self.exportAssets(ordered)
            DispatchQueue.main.async {
                self.setSendingUI(false)
                self.onSend(results)
            }
        }
    }

    private func exportAssets(_ assets: [PHAsset]) -> [PickerResult] {
        var out: [PickerResult] = []
        out.reserveCapacity(assets.count)

        let imgOpts = PHImageRequestOptions()
        imgOpts.isNetworkAccessAllowed = true
        imgOpts.deliveryMode = .highQualityFormat

        let videoOpts = PHVideoRequestOptions()
        videoOpts.isNetworkAccessAllowed = true

        let group = DispatchGroup()
        let lock = NSLock()

        for a in assets {
            switch a.mediaType {
            case .image:
                group.enter()
                caching.requestImage(
                    for: a,
                    targetSize: CGSize(width: a.pixelWidth, height: a.pixelHeight),
                    contentMode: .aspectFit,
                    options: imgOpts
                ) { img, _ in
                    defer { group.leave() }
                    guard let img, let data = img.downscaledJPEGData(maxSide: 2048, quality: 0.7) else { return }
                    lock.lock()
                    out.append(.init(kind: .image(data: data)))
                    lock.unlock()
                }

            case .video:
                group.enter()
                caching.requestAVAsset(forVideo: a, options: videoOpts) { avAsset, _, _ in
                    guard let avAsset else { group.leave(); return }

                    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mp4")

                    if let exporter = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPreset1280x720) {
                        exporter.outputURL = tmp
                        exporter.outputFileType = .mp4
                        exporter.exportAsynchronously {
                            if exporter.status == .completed {
                                lock.lock()
                                out.append(.init(kind: .video(url: tmp)))
                                lock.unlock()
                            }
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                }

            default:
                break
            }
        }

        group.wait()
        return out
    }
}

// MARK: - UICollectionViewDelegate & UIScrollViewDelegate

extension GridViewController: UICollectionViewDelegate, UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }

    // MARK: - Caching Window Updates

    private func updateCachedAssets() {
        guard isViewLoaded && view.window != nil else { return }

        let visibleRect = collectionView.bounds
        let preheatRect = visibleRect.insetBy(dx: 0, dy: -2.0 * visibleRect.height)

        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > collectionView.bounds.height / 6 else { return }

        let (added, removed) = differencesBetweenRects(previousPreheatRect, preheatRect)
        let addedAssets = assets(in: added)
        let removedAssets = assets(in: removed)

        caching.startCachingImages(
            for: addedAssets,
            targetSize: thumbnailPixelSize,
            contentMode: .aspectFill,
            options: nil
        )
        caching.stopCachingImages(
            for: removedAssets,
            targetSize: thumbnailPixelSize,
            contentMode: .aspectFill,
            options: nil
        )

        previousPreheatRect = preheatRect
    }

    // MARK: - Geometry Helpers

    private func assets(in rects: [CGRect]) -> [PHAsset] {
        var idxs: [IndexPath] = []
        for rect in rects {
            let attrs = collectionView.collectionViewLayout.layoutAttributesForElements(in: rect) ?? []
            idxs.append(contentsOf: attrs.map(\.indexPath))
        }
        let unique = Set(idxs)
        return unique.compactMap { idx in
            guard items.indices.contains(idx.item) else { return nil }
            return items[idx.item].asset
        }
    }

    private func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        if old.intersects(new) {
            var added = [CGRect](), removed = [CGRect]()
            if new.maxY > old.maxY {
                added.append(CGRect(x: new.origin.x, y: old.maxY, width: new.width, height: new.maxY - old.maxY))
            }
            if old.minY > new.minY {
                added.append(CGRect(x: new.origin.x, y: new.minY, width: new.width, height: old.minY - new.minY))
            }
            if new.maxY < old.maxY {
                removed.append(CGRect(x: new.origin.x, y: new.maxY, width: new.width, height: old.maxY - new.maxY))
            }
            if old.minY < new.minY {
                removed.append(CGRect(x: new.origin.x, y: old.minY, width: new.width, height: new.minY - new.minY))
            }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }

    // MARK: - Cell Lifecycle

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if items.indices.contains(indexPath.item) {
            let assetID = items[indexPath.item].localID
            if let req = pendingThumb[assetID] {
                caching.cancelImageRequest(req)
                pendingThumb.removeValue(forKey: assetID)
            }
        }
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension GridViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let assets = indexPaths.compactMap { idx in
            items.indices.contains(idx.item) ? items[idx.item].asset : nil
        }
        caching.startCachingImages(for: assets, targetSize: thumbnailPixelSize, contentMode: .aspectFill, options: nil)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let assets = indexPaths.compactMap { idx in
            items.indices.contains(idx.item) ? items[idx.item].asset : nil
        }
        caching.stopCachingImages(for: assets, targetSize: thumbnailPixelSize, contentMode: .aspectFill, options: nil)
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension GridViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in self?.fetchAssets() }
    }
}

// MARK: - UIImage Helpers

private extension UIImage {
    func downscaledJPEGData(maxSide: CGFloat, quality: CGFloat) -> Data? {
        let size = self.size
        let maxCurrentSide = max(size.width, size.height)
        let scale = (maxCurrentSide > maxSide && maxCurrentSide > 0) ? (maxSide / maxCurrentSide) : 1.0
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))

        UIGraphicsBeginImageContextWithOptions(target, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        self.draw(in: CGRect(origin: .zero, size: target))
        let scaled = UIGraphicsGetImageFromCurrentImageContext()
        return scaled?.jpegData(compressionQuality: quality)
    }
}

// MARK: - UIButton.Configuration (Send Button)

extension UIButton.Configuration {
    static func dolyaSend(selectedCount: Int, sending: Bool, sendButton: UIButton) -> UIButton.Configuration {
        var cfg = UIButton.Configuration.filled()
        cfg.cornerStyle = .capsule
        cfg.contentInsets = .init(top: 12, leading: 22, bottom: 12, trailing: 22)
        cfg.titleAlignment = .center

        let baseBlue = UIColor(named: "dolyaBlue") ?? UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)

        let isEnabledNow = (selectedCount > 0) && !sending
        sendButton.isEnabled = isEnabledNow

        let idleTitle = "Надіслати"
        let sendingTitle = "Надсилання"
        let base = sending ? sendingTitle : idleTitle
        let title = selectedCount > 0 ? "\(base) (\(selectedCount))" : base

        var att = AttributedString(title)
        att.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        cfg.attributedTitle = att

        cfg.imagePlacement = .trailing
        cfg.imagePadding = 10
        cfg.preferredSymbolConfigurationForImage = .init(pointSize: 18, weight: .semibold)
        cfg.image = sending ? nil : UIImage(systemName: "paperplane.fill")
        cfg.showsActivityIndicator = sending

        cfg.baseBackgroundColor = baseBlue
        cfg.baseForegroundColor = .white

        let disabledBG = UIColor { tc in
            tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.22, alpha: 1.0)
            : UIColor(white: 0.90, alpha: 1.0)
        }
        let disabledFG = UIColor { tc in
            let alpha: CGFloat = 0.70
            return tc.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(alpha)
            : UIColor.label.withAlphaComponent(alpha)
        }

        cfg.background.backgroundColorTransformer = UIConfigurationColorTransformer { color in
            isEnabledNow ? color : disabledBG
        }

        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.foregroundColor = isEnabledNow ? .white : disabledFG
            return out
        }

        cfg.imageColorTransformer = UIConfigurationColorTransformer { _ in
            isEnabledNow ? .white : disabledFG
        }

        return cfg
    }
}

// MARK: - SendButtonStyle

enum SendButtonStyle {
    struct State { let selectedCount: Int; let sending: Bool }

    static func apply(to button: UIButton, state: State) {
        button.configuration = .dolyaSend(
            selectedCount: state.selectedCount,
            sending: state.sending,
            sendButton: button
        )
        button.alpha = state.sending ? 0.85 : 1.0
    }
}
