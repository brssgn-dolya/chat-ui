//
//  Created by Alex.M on 07.07.2022.
//

import SwiftUI
import CachedAsyncImage

struct AvatarView: View {
    let url: URL?
    let hideAvatar: Bool

    @Environment(\.chatSizes) var chatSizes

    var body: some View {
        CachedAsyncImage(url: url, urlCache: .imageCache) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Rectangle().fill(Color.gray)
        }
        .frame(width: chatSizes.avatar, height: chatSizes.avatar)
        .clipShape(Circle())
        .hidden(hideAvatar)
    }
}

struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        AvatarView(
            url: URL(string: "https://placeimg.com/640/480/sepia"),
            hideAvatar: false
        )
    }
}
