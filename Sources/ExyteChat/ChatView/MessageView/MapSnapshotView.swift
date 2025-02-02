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
    
    var body: some View {
        Group {
            if let snapshotImage {
                Image(uiImage: snapshotImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .onAppear(perform: loadSnapshot)
            }
        }
    }
    
    private func loadSnapshot() {
        let cacheKey = "\(latitude),\(longitude)" as NSString
        
        if let cachedImage = Self.imageCache.object(forKey: cacheKey) {
            snapshotImage = cachedImage
            return
        }
        
        generateSnapshot { image in
            guard let image else { return }
            Self.imageCache.setObject(image, forKey: cacheKey)
            snapshotImage = image
        }
    }
    
    private func generateSnapshot(completion: @escaping (UIImage?) -> Void) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let options = MKMapSnapshotter.Options()
        
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        options.size = CGSize(width: 260, height: 120)
        options.scale = UIScreen.main.scale
        
        MKMapSnapshotter(options: options).start { snapshot, _ in
            guard let snapshot else {
                completion(nil)
                return
            }
            
            let pinImage = UIImage(systemName: "mappin.circle.fill")?.withTintColor(.red, renderingMode: .alwaysOriginal)
            completion(overlayPin(on: snapshot, coordinate: coordinate, pinImage: pinImage))
        }
    }
    
    private func overlayPin(on snapshot: MKMapSnapshotter.Snapshot, coordinate: CLLocationCoordinate2D, pinImage: UIImage?) -> UIImage {
        let image = snapshot.image
        
        UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
        image.draw(at: .zero)
        
        if let pinImage {
            let point = snapshot.point(for: coordinate)
            let pinSize = CGSize(width: 20, height: 20)
            let pinOrigin = CGPoint(x: point.x - pinSize.width / 2, y: point.y - pinSize.height)
            pinImage.draw(in: CGRect(origin: pinOrigin, size: pinSize))
        }
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return finalImage ?? image
    }
}

struct SkeletonView: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.gray.opacity(opacity))
            .frame(width: 260, height: 120)
            .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true), value: opacity)
            .onAppear {
                opacity = 0.7
            }
    }
}
