//
//  PermissionView.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 09.11.2025.
//

import UIKit

final class PermissionView: UIView {

    // MARK: - Callbacks
    var onOpenSettings: (() -> Void)?
    var onClose: (() -> Void)?
    var onNotNow: (() -> Void)?

    // MARK: - UI
    private let backgroundView = UIView()

    private let scrollView = UIScrollView()
    private let scrollContent = UIView()
    private let centerContainer = UIView()

    private let cardView = UIView()
    private let contentStack = UIStackView()

    private let iconContainer = UIView()
    private let iconView = UIImageView(image: UIImage(systemName: "photo.badge.magnifyingglass.fill"))

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)

    private let closeButton = UIButton(type: .system)
    
    private var iconTimer: Timer?

    private enum IconState { case base, gear }
    private var iconState: IconState = .base

    private let baseSymbol = "photo.badge.shield.exclamationmark.fill"
    private let gearSymbol = "gearshape.fill"

    private lazy var toBase = UIImage(systemName: baseSymbol)!
    private lazy var toGear = UIImage(systemName: gearSymbol)!

    // MARK: - Constraints we may rely on
    private var centerMinHeightConstraint: NSLayoutConstraint?

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        updateScrollingIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            stopIconTimer()
        } else {
            startIconTimer()
        }
    }

    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .systemBackground

        // Background
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = .systemGroupedBackground
        addSubview(backgroundView)

        // Scroll
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.bounces = false
        scrollView.isScrollEnabled = false
        addSubview(scrollView)

        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(scrollContent)

        centerContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollContent.addSubview(centerContainer)

        // Card
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 28
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowRadius = 18
        cardView.layer.shadowOffset = CGSize(width: 0, height: 10)
        centerContainer.addSubview(cardView)

        // Content stack
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        // Icon container
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = .tertiarySystemFill
        iconContainer.layer.cornerRadius = 24
        iconContainer.layer.cornerCurve = .continuous

        iconView.translatesAutoresizingMaskIntoConstraints = false

        // 1) symbols
        let baseSymbol = "photo.badge.shield.exclamationmark.fill"
        let gearSymbol = "gearshape.fill"

        let toBase = UIImage(systemName: baseSymbol)!
        let toGear = UIImage(systemName: gearSymbol)!

        iconView.image = toBase
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .label
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        iconContainer.addSubview(iconView)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Дозвольте доступ до Фото"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        // Subtitle
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Щоб вибирати та надсилати медіа, потрібен доступ до бібліотеки Фото."
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        // Primary button
        var primaryCfg = UIButton.Configuration.filled()
        primaryCfg.baseBackgroundColor = UIColor(named: "dolyaBlue") ?? .systemBlue
        primaryCfg.baseForegroundColor = .white
        primaryCfg.cornerStyle = .large
        primaryCfg.title = "Відкрити Налаштування"
        primaryCfg.buttonSize = .large
        primaryCfg.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        primaryButton.configuration = primaryCfg
        primaryButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        primaryButton.titleLabel?.adjustsFontForContentSizeCategory = true

        // Secondary button
        var secondaryCfg = UIButton.Configuration.plain()
        secondaryCfg.title = "Не зараз"
        secondaryCfg.buttonSize = .large
        secondaryCfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        secondaryButton.configuration = secondaryCfg
        secondaryButton.setTitleColor(.systemBlue, for: .normal) // як у топових — лінк синій
        secondaryButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        secondaryButton.titleLabel?.adjustsFontForContentSizeCategory = true

        // Close button
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .label
        addSubview(closeButton)

        // Stack hierarchy
        let centeredIcon = centered(iconContainer)
        contentStack.addArrangedSubview(centeredIcon)
        contentStack.setCustomSpacing(18, after: centeredIcon)

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)

        contentStack.setCustomSpacing(20, after: subtitleLabel)
        contentStack.addArrangedSubview(primaryButton)
        contentStack.addArrangedSubview(secondaryButton)

        // Constraints
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            centerContainer.topAnchor.constraint(equalTo: scrollContent.topAnchor),
            centerContainer.leadingAnchor.constraint(equalTo: scrollContent.leadingAnchor),
            centerContainer.trailingAnchor.constraint(equalTo: scrollContent.trailingAnchor),
            centerContainer.bottomAnchor.constraint(equalTo: scrollContent.bottomAnchor),

            cardView.centerYAnchor.constraint(equalTo: centerContainer.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: centerContainer.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: centerContainer.trailingAnchor, constant: -20),
            cardView.topAnchor.constraint(greaterThanOrEqualTo: centerContainer.topAnchor, constant: 24),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: centerContainer.bottomAnchor, constant: -24),

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            iconContainer.heightAnchor.constraint(equalToConstant: 96),
            iconContainer.widthAnchor.constraint(equalTo: iconContainer.heightAnchor),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            primaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),

            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            closeButton.widthAnchor.constraint(equalTo: closeButton.heightAnchor)
        ])

        // Min-height constraint for true centering when content fits
        let minH = centerContainer.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
        minH.priority = .required
        minH.isActive = true
        centerMinHeightConstraint = minH
    }
    
    private func startIconTimer() {
        guard iconTimer == nil else { return }

        iconState = .base
        iconView.image = toBase
        iconView.removeAllSymbolEffects()

        iconTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }

            self.iconView.removeAllSymbolEffects()

            self.iconState = (self.iconState == .gear) ? .base : .gear
            let nextImage = (self.iconState == .gear) ? self.toGear : self.toBase

            UIView.transition(
                with: self.iconView,
                duration: 0.28,
                options: [.transitionCrossDissolve, .allowUserInteraction]
            ) {
                self.iconView.image = nextImage
            } completion: { _ in
                guard self.iconState == .gear else { return }
                if #available(iOS 18.0, *) {
                    self.iconView.addSymbolEffect(.rotate, options: .repeating)
                }
            }
        }
    }
    
    private func stopIconTimer() {
        iconTimer?.invalidate()
        iconTimer = nil
        iconView.removeAllSymbolEffects()
    }

    private func setupActions() {
        primaryButton.addAction(UIAction { [weak self] _ in
            self?.onOpenSettings?()
        }, for: .primaryActionTriggered)

        secondaryButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onNotNow?()
            self.onClose?()
        }, for: .primaryActionTriggered)

        closeButton.addAction(UIAction { [weak self] _ in
            self?.onClose?()
        }, for: .primaryActionTriggered)
    }

    // MARK: - Scrolling logic
    private func updateScrollingIfNeeded() {
        layoutIfNeeded()

        // Visible height inside scrollView
        let visibleHeight = scrollView.bounds.height

        // Content height produced by auto-layout (fits system)
        let contentHeight = scrollView.contentSize.height

        // If content fits -> disable scroll completely
        let shouldScroll = contentHeight > (visibleHeight + 1.0)

        scrollView.isScrollEnabled = shouldScroll
        scrollView.bounces = shouldScroll
        scrollView.alwaysBounceVertical = false
    }

    // MARK: - Helpers
    private func centered(_ view: UIView) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)

        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
}
