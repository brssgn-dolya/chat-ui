//
//  RecordingPlayer.swift
//
//
//  Created by Alexandra Afonasova on 21.06.2022.
//

import Combine
import AVFoundation

final class RecordingPlayer: ObservableObject {

    @Published var playing = false
    @Published var duration: Double = 0.0
    @Published var secondsLeft: Double = 0.0
    @Published var progress: Double = 0.0

    private let audioSession = AVAudioSession()

    var didPlayTillEnd = PassthroughSubject<Void, Never>()

    private var recording: Recording?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var loaderDelegate: CryptoResourceLoaderDelegate?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        initializePlayer()
    }

    func initializePlayer() {
        do {
            try audioSession.setCategory(.playback)
            try audioSession.setMode(.default)

            if audioSession.currentRoute.outputs.first?.portType == .builtInSpeaker {
                try audioSession.overrideOutputAudioPort(.speaker)
            }
        } catch let error as NSError {
            print("Audio session configuration failed with error code: \(error.code), description: \(error.localizedDescription)")
            fallbackAudioConfiguration()
        }
    }
    
    func fallbackAudioConfiguration() {
        do {
            try audioSession.setCategory(.playback, mode: .default)
        } catch let error {
            print("Fallback configuration failed with error: \(error.localizedDescription)")
        }
    }

    func pause() {
        player?.pause()
        playing = false
    }

    func togglePlay(_ recording: Recording) {
        if self.recording?.url != recording.url {
            self.recording = recording
            if let url = recording.url {
                setupPlayer(for: url, trackDuration: recording.duration)
            }
        }
        if playing {
            pause()
        } else {
            play()
        }
    }

    func seek(to progress: Double) {
        let goalTime = duration * progress
        player?.seek(to: CMTime(seconds: goalTime, preferredTimescale: 10))
        if !playing {
            play()
        }
    }

    func reset() {
        if playing {
            pause()
        }
        recording = nil
        progress = 0
    }

    private func play() {
        guard !playing else { return }
        do {
            try audioSession.setActive(true)
            player?.play()
            playing = true
            NotificationCenter.default.post(name: .audioPlaybackStarted, object: self)
        } catch {
            print("Failed to activate audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupPlayer(for url: URL, trackDuration: Double) {
        duration = trackDuration
        progress = 0.0
        secondsLeft = trackDuration
        NotificationCenter.default.removeObserver(self)
        timeObserver = nil
        player?.replaceCurrentItem(with: nil)
        
        let playerItem: AVPlayerItem
        
        if let mimeType = recording?.mimeType,
           let recording,
           let key = recording.key,
           let iv = recording.iv,
           let url = recording.url
        {
            let loaderDelegate = CryptoResourceLoaderDelegate(
                url: url,
                key: key,
                iv: iv)
            
            self.loaderDelegate = loaderDelegate
            
            let asset = AVURLAsset(url: loaderDelegate.localStreamingURL, options: [
                "AVURLAssetOutOfBandMIMETypeKey": mimeType
            ])
            
            asset.resourceLoader.setDelegate(
                loaderDelegate,
                queue: DispatchQueue.main
            )
            
            playerItem = AVPlayerItem(asset: asset)
        } else if let mimeType = recording?.mimeType {
            let asset = AVURLAsset(url: url, options: [
                "AVURLAssetOutOfBandMIMETypeKey": mimeType
            ])
            
            playerItem = AVPlayerItem(asset: asset)
        } else {
            playerItem = AVPlayerItem(url: url)
        }
        
        player = AVPlayer(playerItem: playerItem)
        
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    let itemDuration = playerItem.duration.seconds
                    if !itemDuration.isNaN && itemDuration > 0 {
                        self.duration = itemDuration
                        self.secondsLeft = itemDuration
                        initializePlayer()
                    } else {
                        self.duration = trackDuration
                        self.secondsLeft = trackDuration
                        initializePlayer()
                    }
                case .failed:
                    print("Failed to load item: \(String(describing: playerItem.error?.localizedDescription))")
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        setupTimeObserver()
        setupNotificationCenterObservers(for: playerItem)
    }

    private func setupTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 10),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            guard let item = self.player?.currentItem, !item.duration.seconds.isNaN else { return }
            self.duration = item.duration.seconds
            self.progress = time.seconds / item.duration.seconds
            self.secondsLeft = (item.duration - time).seconds.rounded()
        }
    }
}

private extension RecordingPlayer {
    func setupNotificationCenterObservers(for playerItem: AVPlayerItem) {
        
        NotificationCenter.default.addObserver(
            forName: .audioPlaybackStarted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if let sender = notification.object as? RecordingPlayer, sender !== self {
                self.pause()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .recordingStarted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if let sender = notification.object as? Recorder, self.playing {
                self.pause()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .recordingStopped,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            self.initializePlayer()
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.playing = false
            self.player?.seek(to: .zero)
            self.didPlayTillEnd.send()
        }
    }
}
