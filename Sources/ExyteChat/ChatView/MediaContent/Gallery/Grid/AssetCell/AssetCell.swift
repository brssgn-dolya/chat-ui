//
//  AssetCell.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 09.11.2025.
//

import UIKit

final class AssetCell: UICollectionViewCell {
    static let reuseID = "AssetCell"

    var onToggle: ((String) -> Void)?
    var onPeek: (() -> Void)?

    private let imageView = UIImageView()
    private let selectionOverlay = UIView()
    private let videoBadge = VideoBadgeView()
    private let checkButton = UIButton(type: .system)
    private let checkBadgeView = UIView()

    private let bottomScrim = CAGradientLayer()

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

        checkBadgeView.isUserInteractionEnabled = false
        checkBadgeView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        checkBadgeView.layer.borderWidth = 1.0
        checkBadgeView.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        checkBadgeView.layer.shadowColor = UIColor.black.cgColor
        checkBadgeView.layer.shadowOpacity = 0.25
        checkBadgeView.layer.shadowRadius = 4
        checkBadgeView.layer.shadowOffset = CGSize(width: 0, height: 1)

        checkButton.tintColor = .white
        checkButton.setImage(UIImage(systemName: "circle"), for: .normal)
        checkButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        checkButton.addTarget(self, action: #selector(tapToggle), for: .touchUpInside)
        checkButton.backgroundColor = .clear

        contentView.addSubview(imageView)
        contentView.addSubview(selectionOverlay)
        contentView.addSubview(videoBadge)
        contentView.addSubview(checkBadgeView)
        contentView.addSubview(checkButton)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
        videoBadge.translatesAutoresizingMaskIntoConstraints = false
        checkBadgeView.translatesAutoresizingMaskIntoConstraints = false
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

            checkBadgeView.widthAnchor.constraint(equalToConstant: 36),
            checkBadgeView.heightAnchor.constraint(equalToConstant: 36),
            checkBadgeView.centerXAnchor.constraint(equalTo: checkButton.centerXAnchor),
            checkBadgeView.centerYAnchor.constraint(equalTo: checkButton.centerYAnchor),
        ])

        bottomScrim.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.35).cgColor
        ]
        bottomScrim.locations = [0.0, 1.0]
        bottomScrim.contentsScale = UIScreen.main.scale
        contentView.layer.addSublayer(bottomScrim)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapPeek))
        contentView.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()

        bottomScrim.frame = CGRect(x: 0, y: bounds.height - 44, width: bounds.width, height: 44)
        contentView.layer.insertSublayer(bottomScrim, above: imageView.layer)

        checkBadgeView.layer.cornerRadius = 0
        checkBadgeView.layer.shadowPath = UIBezierPath(rect: checkBadgeView.bounds).cgPath
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
            imageView.image = nil
            imageView.alpha = 1.0
        }
    }

    func setSelected(_ on: Bool) {
        selectionOverlay.isHidden = !on
        let name = on ? "checkmark.circle.fill" : "circle"
        checkButton.setImage(UIImage(systemName: name), for: .normal)
    }

    @objc private func tapToggle() {
        print("[Cell] tapToggle id:", representedAssetIdentifier ?? "nil")
        guard let id = representedAssetIdentifier else { return }
        onToggle?(id)
    }

    @objc private func tapPeek() { onPeek?() }
}
