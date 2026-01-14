//
//  VideoBadgeView.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 09.11.2025.
//

import UIKit

final class VideoBadgeView: UIView {
    private static let timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = [.pad]
        return f
    }()

    private let iconView = UIImageView()
    private let timeLabel = UILabel()
    private let hStack = UIStackView()
    private let content = UIView()

    private let contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6)
    private let minHeight: CGFloat = 20

    override init(frame: CGRect) {
        super.init(frame: frame)

        content.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        content.layer.cornerRadius = minHeight / 2
        content.layer.cornerCurve = .continuous
        content.layer.masksToBounds = true

        let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        iconView.image = UIImage(systemName: "video.fill", withConfiguration: cfg)
        iconView.tintColor = .white
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        timeLabel.textColor = .white
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 4
        hStack.isLayoutMarginsRelativeArrangement = false
        hStack.addArrangedSubview(iconView)
        hStack.addArrangedSubview(timeLabel)

        addSubview(content)
        content.addSubview(hStack)
        content.translatesAutoresizingMaskIntoConstraints = false
        hStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),

            hStack.topAnchor.constraint(equalTo: content.topAnchor, constant: contentInsets.top),
            hStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -contentInsets.bottom),
            hStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: contentInsets.leading),
            hStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -contentInsets.trailing),

            content.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight)
        ])

        isAccessibilityElement = false
        accessibilityElementsHidden = true
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func setDuration(_ seconds: TimeInterval?) {
        guard let sec = seconds, sec.isFinite, sec > 0 else {
            isHidden = true
            return
        }
        let floored = TimeInterval(Int(sec))
        if floored >= 3600 {
            Self.timeFormatter.allowedUnits = [.hour, .minute, .second]
        } else {
            Self.timeFormatter.allowedUnits = [.minute, .second]
        }
        timeLabel.text = Self.timeFormatter.string(from: floored)
        isHidden = false
    }
}
