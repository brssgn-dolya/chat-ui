//
//  MessageMapView.swift
//  Chat
//
//  Created by Dolya on 31.01.2025.
//

import SwiftUI
import MapKit

final class MapSnapshotCache {
    static let shared = MapSnapshotCache()
    
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {}
    
    subscript(key: String) -> UIImage? {
        get { cache.object(forKey: key as NSString) }
        set {
            if let newValue = newValue {
                cache.setObject(newValue, forKey: key as NSString)
            }
        }
    }
}

struct MessageMapView: View {
    let latitude: Double
    let longitude: Double
    let snapshotSize: CGSize
    
    private static let regionSpan = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    @State private var snapshotImage: UIImage?
    
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
        let cacheKey = makeCacheKey()
        
        if let cachedImage = MapSnapshotCache.shared[cacheKey] {
            snapshotImage = cachedImage
            return
        }
        
        do {
            let image = try await generateSnapshot()
            MapSnapshotCache.shared[cacheKey] = image
            snapshotImage = image
        } catch {
            print("Error loading snapshot: \(error.localizedDescription)")
        }
    }
    
    private func makeCacheKey() -> String {
        "\(latitude)_\(longitude)_\(Int(snapshotSize.width))x\(Int(snapshotSize.height))"
    }
    
    private func generateSnapshot() async throws -> UIImage {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(center: coordinate, span: Self.regionSpan)
        
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = snapshotSize
        options.scale = UIScreen.main.scale
        
        return try await MKMapSnapshotter(options: options).snapshotAsync().image
    }
}


enum MKMapSnapshotterError: Error {
    static let unknownError = NSError(domain: "MKMapSnapshotterError", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Unknown error occurred while creating the snapshot."
    ])
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

