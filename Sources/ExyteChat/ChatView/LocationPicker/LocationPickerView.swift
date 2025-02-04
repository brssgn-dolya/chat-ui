//
//  LocationPickerView.swift
//  Chat
//
//  Created by Dolya on 31.01.2025.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

struct LocationPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var locationManager = LocationManager()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
    )
    
    @State private var selectedLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    
    var onSelectLocation: (CLLocationCoordinate2D) -> Void
    
    private let locationUpdatePublisher = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var locationUpdateCancellable: AnyCancellable?
    @State private var showAlert = false
    
    var body: some View {
        VStack {
            ZStack {
                Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true)
                    .edgesIgnoringSafeArea(.all)
                    .onReceive(locationManager.$userLocation) { newLocation in
                        if let newLocation = newLocation {
                            DispatchQueue.main.async {
                                self.region = MKCoordinateRegion(
                                    center: newLocation,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                )
                                self.selectedLocation = newLocation
                            }
                        }
                    }
                
                VStack {
                    Image(systemName: "mappin.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.red)
                        .offset(y: -20)
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 10, height: 10)
                        .offset(y: -5)
                }
                
            }
            
            Spacer()
            
            VStack(spacing: 10) {
                Text("Перемістіть карту, щоб вибрати місце")
                    .font(.headline)
                    .padding(.bottom, 16)
                if locationManager.isLocationDenied {
                    Button(action: {
                        showAlert = true
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Поділитися геоданими")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    
                    .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("Доступ до геопозиції вимкнено"),
                            message: Text("Щоб надати доступ, перейдіть у Налаштування > Геопозиція."),
                            primaryButton: .default(Text("Налаштування"), action: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }),
                            secondaryButton: .cancel(Text("Скасувати"))
                        )
                    }
                }
                
                Button(action: {
                    onSelectLocation(selectedLocation)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Надіслати розташування")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Скасувати")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(UIColor.systemGray4))
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGray6))
        .onAppear {
            locationUpdateCancellable = locationUpdatePublisher.sink { _ in
                let newCenter = region.center
                if newCenter.latitude != selectedLocation.latitude ||
                    newCenter.longitude != selectedLocation.longitude {
                    selectedLocation = newCenter
                }
            }
        }
        .onDisappear {
            locationUpdateCancellable?.cancel()
            locationUpdateCancellable = nil
        }
    }
}

// MARK: - Location Manager
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isLocationDenied = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManagerDidChangeAuthorization(locationManager)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            switch manager.authorizationStatus {
            case .notDetermined:
                self.locationManager.requestWhenInUseAuthorization()
            case .restricted, .denied:
                self.isLocationDenied = true
                self.userLocation = nil
            case .authorizedWhenInUse, .authorizedAlways:
                self.isLocationDenied = false
                self.locationManager.startUpdatingLocation()
            case .notDetermined:
                self.isLocationDenied = false
            @unknown default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            DispatchQueue.main.async {
                self.userLocation = location.coordinate
                self.locationManager.stopUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .denied {
            DispatchQueue.main.async {
                self.isLocationDenied = true
                self.userLocation = nil
            }
        }
    }
}
