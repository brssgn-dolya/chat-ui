//
//  MapSnapshotView.swift
//  Chat
//
//  Created by Dolya on 31.01.2025.
//

import SwiftUI
import MapKit
import CryptoKit

struct MapSnapshotView: View {
    let latitude: Double
    let longitude: Double
    
    private let encryptionKeyIdentifier = "com.dolya.secchat.monal.mapsnapshotkey"
    
    @State private var snapshotImage: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let snapshotImage = snapshotImage {
                    Image(uiImage: snapshotImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                        .clipped()
                } else {
                    mapPlaceholderView()
                }
                Image(systemName: "mappin.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .offset(y: -10)
                    .foregroundColor(.red)
            }
            .task {
                await loadSnapshot(for: geometry.size)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                Task.detached {
                    try await MapSnapshotFileCache.shared.clearCache()
                }
            }
        }
    }
    
    @ViewBuilder
    private func mapPlaceholderView() -> some View {
        GeometryReader { geometry in
            Image("map_placeholder")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay {
                    Image(systemName: "mappin.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .offset(y: -10)
                        .foregroundColor(.red)
                }
        }
    }
    
    private func loadSnapshot(for size: CGSize) async {
        let cacheKey = "\(latitude)-\(longitude)-\(Int(size.width))x\(Int(size.height))"
        
        do {
            let encryptionKey = try await KeychainHelper.shared.getOrCreateSymmetricKey(for: encryptionKeyIdentifier)
            
            if let encryptedImageData = try await MapSnapshotFileCache.shared.encryptedImageData(forKey: cacheKey) {
                let decryptedData = try KeychainHelper.shared.decryptData(encryptedImageData, using: encryptionKey)
                if let image = UIImage(data: decryptedData) {
                    await MainActor.run {
                        self.snapshotImage = image
                    }
                }
                return
            }
            
            let options = MKMapSnapshotter.Options()
            options.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            options.size = size
            options.scale = UIScreen.main.scale
            
            let snapshotter = MKMapSnapshotter(options: options)
            
            let result = try await withCheckedThrowingContinuation { continuation in
                snapshotter.start { snapshot, error in
                    if let snapshot = snapshot {
                        continuation.resume(returning: snapshot)
                    } else {
                        continuation.resume(throwing: error ?? NSError(domain: "SnapshotError", code: -1, userInfo: nil))
                    }
                }
            }
            
            let maxCacheSize: UInt64 = 50 * 1024 * 1024 // 50 MB
            
            if let imageData = result.image.pngData() {
                let encryptedData = try KeychainHelper.shared.encryptData(imageData, using: encryptionKey)
                try await MapSnapshotFileCache.shared.setEncryptedImageData(encryptedData, forKey: cacheKey)
                try await MapSnapshotFileCache.shared.limitCacheSize(to: maxCacheSize)
            }
            
            await MainActor.run {
                self.snapshotImage = result.image
            }
            
        } catch {
            print("❌ Error in loadSnapshot: \(error.localizedDescription)")
        }
    }
}

// MARK: - Using Map

//struct MapSnapshotView: View {
//    let latitude: Double
//    let longitude: Double
//
//    private var region: MKCoordinateRegion {
//        MKCoordinateRegion(
//            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
//            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
//        )
//    }
//
//    var body: some View {
//        ZStack {
//            Map(coordinateRegion: .constant(region), interactionModes: [])
//                .frame(maxHeight: .infinity)
//                .overlay(alignment: .center) {
//                    Image(systemName: "mappin.circle.fill")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 20, height: 20)
//                        .offset(y: -10)
//                        .foregroundColor(Color(UIColor.systemRed))
//                }
//        }
//    }
//}

// MARK: - Using MKMapView

//import SwiftUI
//import MapKit
//
//struct MapSnapshotView: View {
//    let latitude: Double
//    let longitude: Double
//
//    var body: some View {
//        ZStack {
//            MapView(latitude: latitude, longitude: longitude)
//                .frame(maxHeight: .infinity)
//                .overlay(alignment: .center) {
//                    Image(systemName: "mappin.circle.fill")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 20, height: 20)
//                        .offset(y: -10)
//                        .foregroundColor(Color(UIColor.systemRed))
//                }
//        }
//    }
//}
//
//struct MapView: UIViewRepresentable {
//    let latitude: Double
//    let longitude: Double
//
//    func makeUIView(context: Context) -> MKMapView {
//        let mapView = MKMapView()
//        mapView.isUserInteractionEnabled = false  
//        mapView.isScrollEnabled = false
//        mapView.isZoomEnabled = false
//        mapView.isPitchEnabled = false
//        mapView.isRotateEnabled = false
//        mapView.showsUserLocation = false
//        mapView.layer.contentsGravity = .resizeAspectFill
//        
//        updateMapView(mapView)
//        return mapView
//    }
//
//    func updateUIView(_ uiView: MKMapView, context: Context) {
//        updateMapView(uiView)
//    }
//
//    private func updateMapView(_ mapView: MKMapView) {
//          let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
//          let newRegion = MKCoordinateRegion(
//              center: coordinate,
//              span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
//          )
//
//          if mapView.region.center.latitude != coordinate.latitude ||
//              mapView.region.center.longitude != coordinate.longitude {
//              mapView.setRegion(newRegion, animated: false)
//          }
//      }
//}
//
//
