//
//  NetworkMonitor.swift
//  
//
//  Created by Alisa Mylnikova on 01.09.2023.
//

import Foundation
import Network

public final class NetworkConnectivityMonitor: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let workerQueue = DispatchQueue(label: "com.sonata.network-conectivity-monitor")

    @Published public private(set) var isConnected = false

    public init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let newStatus = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                if self.isConnected != newStatus {
                    self.isConnected = newStatus
                }
            }
        }
        networkMonitor.start(queue: workerQueue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
}
