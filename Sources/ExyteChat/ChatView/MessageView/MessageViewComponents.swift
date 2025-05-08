//
//  MessageViewComponents.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 08.05.2025.
//

import SwiftUI
import MapKit

public struct MessageViewComponents {
    
    @ViewBuilder
    public static func attachmentsView(_ message: Message, tapped: @escaping (Attachment) -> Void) -> some View {
        AttachmentsGrid(attachments: message.attachments) {
            tapped($0)
        }
        .applyIf(message.attachments.count > 1) {
            $0
                .padding(.top, 1)
                .padding(.horizontal, 1)
        }
        .bubbleBackground()
    }
    
    @ViewBuilder
    public static func locationView(_ message: Message, openMaps: @escaping (Double, Double) -> Void) -> some View {
        let coordinates = parseCoordinates(from: message.text)
        let size = CGSize(width: min(UIScreen.main.bounds.width * 0.6, 260), height: 128)
        
        if let lat = coordinates?.latitude, let lon = coordinates?.longitude {
            ZStack {
                MessageMapView(latitude: lat, longitude: lon, snapshotSize: size)
                    .frame(width: size.width, height: size.height)
                    .cornerRadius(20)
//                    .highPriorityGesture(
//                        TapGesture().onEnded {
//                            openMaps(lat, lon)
//                        }
//                    )
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
            .bubbleBackground()
        }
    }
    
    @ViewBuilder
    public static func timeView(text: String, needsCapsule: Bool = false) -> some View {
        if needsCapsule {
            Text(text)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background {
                    Capsule()
                        .fill(Color.black.opacity(0.3))
                }
        } else {
            Text(text)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
    }
    
    @ViewBuilder
    public static func audioPreviewView(_ recording: Recording, message: Message) -> some View {
        RecordWaveformWithButtons(
            recording: recording,
            colorButton: .dolyaBlue,
            colorButtonBg: .white,
            colorWaveform: .white
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .bubbleBackground()
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    public static func documentView(_ message: Message) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc")
                .resizable()
                .foregroundStyle(.white)
                .scaledToFit()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text.components(separatedBy: "-").first ?? "")
                    .font(.body)
                    .lineLimit(1)
                Text(message.text.components(separatedBy: "-").last ?? "")
                    .font(.footnote)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .bubbleBackground()
    }
    
    private static func parseCoordinates(from text: String) -> (latitude: Double, longitude: Double)? {
        let cleanText = text.replacingOccurrences(of: "geo:", with: "")
        let components = cleanText.split(separator: ";").first?.split(separator: ",").compactMap { Double($0) }
        if let lat = components?.first, let lon = components?.last {
            return (latitude: lat, longitude: lon)
        }
        return nil
    }
}

public extension View {
    @ViewBuilder
    func bubbleBackground() -> some View {
        self
            .foregroundColor(.white)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .foregroundColor(.dolyaBlue)
            }
            .cornerRadius(20)
    }
}

extension Color {
    static let dolyaBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
}
