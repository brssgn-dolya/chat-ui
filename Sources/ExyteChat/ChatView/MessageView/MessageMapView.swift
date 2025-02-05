//
//  MessageMapView.swift
//  Chat
//
//  Created by Dolya on 31.01.2025.
//

import SwiftUI
import MapKit

struct MessageMapView: View {
    let latitude: Double
    let longitude: Double
    
    var body: some View {
        ZStack {
            MessageMapViewRepresentable(latitude: latitude, longitude: longitude)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .center) {
                    Image(systemName: "mappin.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .offset(y: -10)
                        .foregroundColor(Color(UIColor.systemRed))
                }
        }
    }
}

struct MessageMapViewRepresentable: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsUserLocation = false
        mapView.layer.contentsGravity = .resizeAspectFill
        
        updateMapView(mapView)
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        updateMapView(uiView)
    }
    
    private func updateMapView(_ mapView: MKMapView) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let newRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        
        let threshold: Double = 0.00001
        let currentCenter = mapView.region.center
        
        if abs(currentCenter.latitude - coordinate.latitude) > threshold ||
            abs(currentCenter.longitude - coordinate.longitude) > threshold {
            mapView.setRegion(newRegion, animated: false)
        }
    }
}


