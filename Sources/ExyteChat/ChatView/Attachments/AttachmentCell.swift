//
//  Created by Alex.M on 16.06.2022.
//

import SwiftUI

struct AttachmentCell: View {

    @Environment(\.chatTheme) private var theme

    let attachment: Attachment
    let onTap: (Attachment) -> Void

    var body: some View {
        Group {
            if attachment.type == .image {
                content
            } else if attachment.type == .video {
                content
                    .overlay {
                        theme.images.message.playVideo
                            .resizable()
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                    }
            } else {
                content
                    .overlay {
                        Text("Unknown")
                    }
            }
        }
        .highPriorityGesture(TapGesture().onEnded {
            onTap(attachment)
        })
    }

    var content: some View {
        AsyncImageView(url: attachment.thumbnail, imageData: attachment.thumbnailData)
    }
}

struct AsyncImageView: View {

    @Environment(\.chatTheme) var theme
    let url: URL?
    let imageData: Data?

    var body: some View {
        if let url {
            CachedAsyncImage(url: url, urlCache: .imageCache) { imageView in
                imageView
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    Rectangle()
                        .foregroundColor(theme.colors.inputLightContextBackground)
                        .frame(minWidth: 100, minHeight: 100)
                    ActivityIndicator(size: 30, showBackground: false)
                }
            }
        } else if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
    }
}
