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
            clearOldCache()
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
                    .offset(y: -10)
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
            if let pinImage = UIImage(systemName: "mappin.circle.fill")?
                .withTintColor(.red, renderingMode: .alwaysOriginal) {
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

extension MapSnapshotView {
    private func clearOldCache() {
        let fileManager = FileManager.default
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }

        DispatchQueue.global(qos: .background).async {

            if let files = try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], options: .skipsHiddenFiles) {
                let expirationInterval: TimeInterval = 7 * 24 * 60 * 60
                let maxCacheSize: Int64 = 50 * 1024 * 1024
                let now = Date()
                var totalSize: Int64 = 0
                var filesToDelete: [(URL, Date, Int64)] = []

                for file in files {
                    if let attrs = try? file.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                       let creationDate = attrs.creationDate,
                       let fileSize = attrs.fileSize {
                        totalSize += Int64(fileSize)

                        if now.timeIntervalSince(creationDate) > expirationInterval {
                            filesToDelete.append((file, creationDate, Int64(fileSize)))
                        }
                    }
                }

                for (file, _, fileSize) in filesToDelete {
                    do {
                        try fileManager.removeItem(at: file)
                        totalSize -= fileSize
                        #if DEBUG
                        print("🗑 Видалено застарілий файл: \(file.lastPathComponent)")
                        #endif
                    } catch {
                        print("❌ Помилка видалення файлу: \(file.lastPathComponent), \(error.localizedDescription)")
                    }
                }

                if totalSize > maxCacheSize {
                    let sortedFiles = files.compactMap { file -> (URL, Date)? in
                        if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate {
                            return (file, creationDate)
                        }
                        return nil
                    }.sorted { $0.1 < $1.1 }

                    for (file, _) in sortedFiles {
                        if let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                            do {
                                try fileManager.removeItem(at: file)
                                totalSize -= Int64(fileSize)
                                #if DEBUG
                                print("🗑 Видалено файл для звільнення місця: \(file.lastPathComponent)")
                                #endif

                                if totalSize <= maxCacheSize { break }
                            } catch {
                                print("❌ Помилка видалення файлу: \(file.lastPathComponent), \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }
}

