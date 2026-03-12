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

    @Published public private(set) var isNetworkAvailable: Bool? = nil

    public init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let newStatus = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                if self.isNetworkAvailable != newStatus {
                    self.isNetworkAvailable = newStatus
                }
            }
        }
        networkMonitor.start(queue: workerQueue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
}
