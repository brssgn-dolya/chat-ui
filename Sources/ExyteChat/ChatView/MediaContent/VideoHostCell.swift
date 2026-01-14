//
//  VideoHostCell.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 09.11.2025.
//


import UIKit

// MARK: - VideoHostCell

final class VideoHostCell: UICollectionViewCell {
    static let reuseId = "vid"

    let container = UIView()
    let spinner = UIActivityIndicatorView(style: .large)

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .black
        container.backgroundColor = .black
        contentView.addSubview(container)
        contentView.addSubview(spinner)
        container.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        spinner.startAnimating()
    }
}
