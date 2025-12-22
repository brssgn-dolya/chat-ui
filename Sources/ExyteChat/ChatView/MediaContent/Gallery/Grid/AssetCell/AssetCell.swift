//
//  AssetCell.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 09.11.2025.
//

import UIKit

final class AssetCell: UICollectionViewCell {
    static let reuseID = "AssetCell"

    var onToggle: (() -> Void)?
    var onPeek: (() -> Void)?

    private let imageView = UIImageView()
    private let selectionOverlay = UIView()
    private let videoBadge = VideoBadgeView()
    private let checkButton = UIButton(type: .system)

    private let bottomScrim = CAGradientLayer()
    private let shimmerLayer = CAGradientLayer()
    private var isShimmering = false

    var representedAssetIdentifier: String?

    var targetSize: CGSize {
        let s = contentView.bounds.size
        let scale = UIScreen.main.scale
        let w = max(2, s.width * scale)
        let h = max(2, s.height * scale)
        return CGSize(width: w, height: h)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isAccessibilityElement = false

        selectionOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        selectionOverlay.isHidden = true
        selectionOverlay.isUserInteractionEnabled = false

        checkButton.tintColor = .white
        checkButton.setImage(UIImage(systemName: "circle"), for: .normal)
        checkButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        checkButton.addTarget(self, action: #selector(tapToggle), for: .touchUpInside)

        contentView.addSubview(imageView)
        contentView.addSubview(selectionOverlay)
        contentView.addSubview(videoBadge)
        contentView.addSubview(checkButton)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
        videoBadge.translatesAutoresizingMaskIntoConstraints = false
        checkButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            selectionOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            videoBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            videoBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            checkButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            checkButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            checkButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            checkButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])

        bottomScrim.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.35).cgColor
        ]
        bottomScrim.locations = [0.0, 1.0]
        bottomScrim.contentsScale = UIScreen.main.scale
        contentView.layer.addSublayer(bottomScrim)

        configureShimmer()

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapPeek))
        contentView.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        bottomScrim.frame = CGRect(x: 0, y: bounds.height - 44, width: bounds.width, height: 44)
        contentView.layer.insertSublayer(bottomScrim, above: imageView.layer)

        shimmerLayer.frame = contentView.bounds
        if shimmerLayer.superlayer == nil {
            contentView.layer.insertSublayer(shimmerLayer, below: imageView.layer)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedAssetIdentifier = nil
        imageView.image = nil
        imageView.layer.removeAllAnimations()
        imageView.alpha = 1.0

        selectionOverlay.isHidden = true
        setSelected(false)
        videoBadge.isHidden = true

        startShimmer()
    }

    func configure(with image: UIImage?, isVideo: Bool, duration: TimeInterval, isSelected: Bool) {
        setSelected(isSelected)
        bottomScrim.isHidden = !isVideo

        if isVideo {
            videoBadge.setDuration(duration)
        } else {
            videoBadge.isHidden = true
        }

        if let img = image {
            if isShimmering { stopShimmer() }
            if imageView.image == nil {
                imageView.alpha = 0.0
                imageView.image = img
                UIView.animate(withDuration: 0.15, delay: 0.0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                    self.imageView.alpha = 1.0
                }
            } else {
                imageView.image = img
            }
        } else {
            startShimmer()
            imageView.image = nil
            imageView.alpha = 1.0
        }
    }

    func setSelected(_ on: Bool) {
        selectionOverlay.isHidden = !on
        let name = on ? "checkmark.circle.fill" : "circle"
        checkButton.setImage(UIImage(systemName: name), for: .normal)
    }

    @objc private func tapToggle() { onToggle?() }
    @objc private func tapPeek() { onPeek?() }
}

private extension AssetCell {
    func configureShimmer() {
        let base = UIColor.secondarySystemFill.cgColor
        let glow = UIColor.tertiarySystemFill.withAlphaComponent(0.6).cgColor
        shimmerLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        shimmerLayer.endPoint   = CGPoint(x: 1.0, y: 0.5)
        shimmerLayer.colors = [base, glow, base]
        shimmerLayer.locations = [0.0, 0.5, 1.0]
        shimmerLayer.isHidden = true
        shimmerLayer.masksToBounds = true
        shimmerLayer.contentsScale = UIScreen.main.scale
    }

    func startShimmer() {
        guard !isShimmering else { return }
        isShimmering = true
        shimmerLayer.isHidden = false

        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = [-0.5, -0.25, 0.0]
        anim.toValue   = [1.0, 1.25, 1.5]
        anim.duration  = 1.25
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        shimmerLayer.add(anim, forKey: "shimmer.locations")
    }

    func stopShimmer() {
        guard isShimmering else { return }
        isShimmering = false
        shimmerLayer.removeAnimation(forKey: "shimmer.locations")
        shimmerLayer.isHidden = true
    }
}
