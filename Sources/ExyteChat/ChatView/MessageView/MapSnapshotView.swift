//
//  MapSnapshotView.swift
//  Chat
//
//  Created by Dolya on 31.01.2025.
//

import SwiftUI
import MapKit
import Photos

struct MapSnapshotView: View {
    let latitude: Double
    let longitude: Double

    @State private var snapshotImage: UIImage?
    
    private static let imageCache = NSCache<NSString, UIImage>()

    var body: some View {
        Group {
            if let snapshotImage {
                Image(uiImage: snapshotImage)
                    .resizable()
                    .scaledToFill()
            } else {
                SkeletonView()
                
                    .task {
                        await loadSnapshot()
                    }
            }
        }
    }

    private func loadSnapshot() async {
        let cacheKey = "\(latitude),\(longitude)" as NSString
        
        if let cachedImage = Self.imageCache.object(forKey: cacheKey) {
            snapshotImage = cachedImage
            return
        }

        if let image = await generateSnapshot() {
            Self.imageCache.setObject(image, forKey: cacheKey)
            snapshotImage = image
        }
    }

    private func generateSnapshot() async -> UIImage? {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        options.size = CGSize(width: 260, height: 120)
        options.scale = UIScreen.main.scale
        options.mapType = .mutedStandard // Вимикає зайві елементи
        options.showsPointsOfInterest = false // Прибирає назви вулиць
        
        return await withCheckedContinuation { continuation in
            MKMapSnapshotter(options: options).start { snapshot, _ in
                guard let snapshot else {
                    continuation.resume(returning: nil)
                    return
                }
                let pinImage = UIImage(systemName: "mappin.circle.fill")?.withTintColor(.red, renderingMode: .alwaysOriginal)
                continuation.resume(returning: overlayPin(on: snapshot, coordinate: coordinate, pinImage: pinImage))
            }
        }
    }

    private func overlayPin(on snapshot: MKMapSnapshotter.Snapshot, coordinate: CLLocationCoordinate2D, pinImage: UIImage?) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)
            
            if let pinImage {
                let point = snapshot.point(for: coordinate)
                let pinSize = CGSize(width: 20, height: 20)
                let pinOrigin = CGPoint(x: point.x - pinSize.width / 2, y: point.y - pinSize.height)
                pinImage.draw(in: CGRect(origin: pinOrigin, size: pinSize))
            }
        }
    }

}

struct SkeletonView: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        ZStack {
            Image("map_placeholder")
                .overlay {
                    overlayPin()
                }

        }
    }
    
    @ViewBuilder
    private func overlayPin() -> some View {
        GeometryReader { geo in
            let pinSize = CGSize(width: 20, height: 20)
            let point = convertCoordinateToPoint(in: geo.size)

            Image(systemName: "mappin.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: pinSize.width, height: pinSize.height)
                .foregroundColor(.red)
                .position(x: point.x, y: point.y - pinSize.height / 2)
        }
    }

    private func convertCoordinateToPoint(in size: CGSize) -> CGPoint {
        let x = size.width / 2
        let y = size.height / 2
        return CGPoint(x: x, y: y)
    }
}
