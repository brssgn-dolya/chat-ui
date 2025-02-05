//
//  MessageMapView.swift
//  Chat
//
//  Created by Dolya on 31.01.2025.
//

import SwiftUI
import MapKit

final class MapSnapshotCache {
    private var cache = NSCache<NSString, UIImage>()
    static let shared = MapSnapshotCache()
    
    func get(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

struct MessageMapView: View {
    let latitude: Double
    let longitude: Double
    let snapshotSize: CGSize
    let regionSpan = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    
    private var cache = MapSnapshotCache.shared
    @State private var snapshotImage: UIImage?
    
    init(latitude: Double, longitude: Double, snapshotSize: CGSize) {
        self.latitude = latitude
        self.longitude = longitude
        self.snapshotSize = snapshotSize
    }
    
    var body: some View {
        ZStack {
            snapshotView
            pinOverlay
        }
        .frame(width: snapshotSize.width, height: snapshotSize.height)
        .task {
            await loadSnapshot()
        }
    }
    
    private var snapshotView: some View {
        Image(uiImage: snapshotImage ?? UIImage(named: "map_placeholder")!)
            .resizable()
            .scaledToFill()
            .clipped()
    }
    
    private var pinOverlay: some View {
        Image(systemName: "mappin.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .offset(y: -10)
            .foregroundColor(.red)
    }
    
    private func loadSnapshot() async {
        let cacheKey = "\(latitude)_\(longitude)_\(Int(snapshotSize.width))x\(Int(snapshotSize.height))"
        
        if let cachedImage = cache.get(forKey: cacheKey) {
            await MainActor.run { self.snapshotImage = cachedImage }
            return
        }
        do {
            let snapshot = try await generateSnapshot(size: snapshotSize)
            let image = snapshot.image
            cache.set(image, forKey: cacheKey)
            await MainActor.run { self.snapshotImage = image }
        } catch {
            print("Помилка завантаження знімка: \(error.localizedDescription)")
        }
    }
    
    private func generateSnapshot(size: CGSize) async throws -> MKMapSnapshotter.Snapshot {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(center: coordinate, span: regionSpan)
        
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = UIScreen.main.scale
        
        return try await MKMapSnapshotter(options: options).snapshotAsync()
    }
}

enum MKMapSnapshotterError: Error {
    case unknownError
}

extension MKMapSnapshotter {
    func snapshotAsync() async throws -> Snapshot {
        try await withCheckedThrowingContinuation { continuation in
            start { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let snapshot = snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: MKMapSnapshotterError.unknownError)
                }
            }
        }
    }
}

