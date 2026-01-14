//
//  LimitedGalleryEmptyStateView.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 22.12.2025.
//

import UIKit

final class LimitedGalleryEmptyStateView: UIView {

    var onPickMore: (() -> Void)?
    var onClose: (() -> Void)?

    private let iconView = UIImageView(image: UIImage(systemName: "photo.badge.plus"))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let button = UIButton(type: .system)
    private let stack = UIStackView()

    private let closeButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        isHidden = true
        backgroundColor = .systemBackground

        // Close button
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .label
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        closeButton.addAction(UIAction { [weak self] _ in
            self?.onClose?()
        }, for: .primaryActionTriggered)
        addSubview(closeButton)

        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .secondaryLabel
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Немає доступних фото"
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        // Subtitle
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "У вас лімітований доступ до Фото. Оберіть фото, щоб вони зʼявилися в галереї."
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        // Primary button
        var cfg = UIButton.Configuration.filled()
        cfg.cornerStyle = .large
        cfg.buttonSize = .large
        cfg.title = "Обрати більше"
        cfg.contentInsets = .init(top: 14, leading: 18, bottom: 14, trailing: 18)
        button.configuration = cfg

        button.addAction(UIAction { [weak self] _ in
            self?.onPickMore?()
        }, for: .primaryActionTriggered)

        // Stack
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.setCustomSpacing(20, after: subtitleLabel)
        stack.addArrangedSubview(button)

        addSubview(stack)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            iconView.heightAnchor.constraint(equalToConstant: 88),
            iconView.widthAnchor.constraint(equalTo: iconView.heightAnchor),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),

            button.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }
}
