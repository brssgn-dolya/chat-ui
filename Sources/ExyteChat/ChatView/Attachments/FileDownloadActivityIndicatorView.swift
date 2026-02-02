//
//  FileDownloadActivityIndicatorView.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 18.01.2026.
//

import SwiftUI

struct FileDownloadActivityIndicatorView: UIViewRepresentable {
    let style: UIActivityIndicatorView.Style

    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let v = UIActivityIndicatorView(style: style)
        v.hidesWhenStopped = false
        v.startAnimating()
        return v
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        if !uiView.isAnimating {
            uiView.startAnimating()
        }
    }
}
