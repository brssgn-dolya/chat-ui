//
//  Created by Alex.M on 07.07.2022.
//

import SwiftUI

struct AvatarView: View {

    let url: URL?
    let cachedImage: UIImage?
    let avatarSize: CGFloat

    var body: some View {
        if let cachedImage = cachedImage {
            Image(uiImage: cachedImage)
                .resizable()
                .scaledToFill()
                .viewSize(avatarSize)
                .clipShape(Circle())
        } else {
            CachedAsyncImage(url: url, urlCache: .imageCache) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.gray)
            }
            .viewSize(avatarSize)
            .clipShape(Circle())
        }
    }
}

struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        AvatarView(
            url: URL(string: "https://placeimg.com/640/480/sepia"),
            cachedImage: nil,
            avatarSize: 32
        )
    }
}
