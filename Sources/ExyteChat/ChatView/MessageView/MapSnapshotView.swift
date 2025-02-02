//
//  MapSnapshotView.swift
//  Chat
//
//  Created by Dolya on 31.01.2025.
//

import SwiftUI
import MapKit

struct MapSnapshotView: View {
    let latitude: Double
    let longitude: Double

    @State private var snapshotImage: UIImage?
    private static let imageCache = NSCache<NSString, UIImage>()
    
    private var cachedImage: UIImage? {
        getCachedImage(for: cacheKeyForCurrentLocation())
    }

    var body: some View {
        ZStack {
            if let snapshotImage {
                Image(uiImage: snapshotImage)
                    .resizable()
                    .scaledToFill()
            } else {
                mapPlaceholderView()
            }
        }
        .onAppear {
            if let cached = cachedImage {
                snapshotImage = cached
            } else {
                Task {
                    await generateAndCacheSnapshot()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            clearMemoryCache()
        }
    }

    @ViewBuilder
    private func mapPlaceholderView() -> some View {
        Image("map_placeholder")
            .resizable()
            .scaledToFill()
            .overlay(alignment: .center) {
                Image(systemName: "mappin.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.red)
            }
    }

    private func generateAndCacheSnapshot() async {
        if let image = await generateSnapshot() {
            DispatchQueue.global(qos: .background).async {
                self.saveImageToCache(image, key: self.cacheKeyForCurrentLocation())
            }
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
        options.scale = 2.0
        options.mapType = .mutedStandard
        options.showsPointsOfInterest = false
        options.showsBuildings = false

        return await withCheckedContinuation { continuation in
            MKMapSnapshotter(options: options).start { snapshot, _ in
                continuation.resume(returning: snapshot.map { overlayPin(on: $0, coordinate: coordinate) })
            }
        }
    }

    private func overlayPin(on snapshot: MKMapSnapshotter.Snapshot, coordinate: CLLocationCoordinate2D) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
        return renderer.image { _ in
            snapshot.image.draw(at: .zero)
            if let pinImage = UIImage(systemName: "mappin.circle.fill")?.withRenderingMode(.alwaysOriginal) {
                let point = snapshot.point(for: coordinate)
                pinImage.draw(in: CGRect(origin: CGPoint(x: point.x - 10, y: point.y - 20), size: CGSize(width: 20, height: 20)))
            }
        }
    }

    private func cacheKeyForCurrentLocation() -> NSString {
        return "\(latitude),\(longitude)" as NSString
    }

    private func getCachedImage(for key: NSString) -> UIImage? {
        if let cachedImage = Self.imageCache.object(forKey: key) {
            return cachedImage
        }
        if let diskImage = loadImageFromDisk(key as String) {
            Self.imageCache.setObject(diskImage, forKey: key)
            return diskImage
        }
        return nil
    }

    private func saveImageToCache(_ image: UIImage, key: NSString) {
        Self.imageCache.setObject(image, forKey: key)
        saveImageToDisk(image, key: key as String)
    }

    private func clearMemoryCache() {
        Self.imageCache.removeAllObjects()
    }

    private func getCacheURL(for key: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("\(key).png")
    }

    private func loadImageFromDisk(_ key: String) -> UIImage? {
        guard let data = try? Data(contentsOf: getCacheURL(for: key)) else { return nil }
        return UIImage(data: data)
    }

    private func saveImageToDisk(_ image: UIImage, key: String) {
        if let data = image.pngData() {
            try? data.write(to: getCacheURL(for: key))
        }
    }
}
