//
//  NetworkMonitor.swift
//  
//
//  Created by Alisa Mylnikova on 01.09.2023.
//

import Foundation
import Network

public final class NetworkMonitor: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let workerQueue = DispatchQueue(label: "com.sonata.network.monitor")
    
    @Published public private(set) var isConnected: Bool = false

    public init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let newStatus = path.status == .satisfied
            if self.isConnected != newStatus {
                DispatchQueue.main.async {
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
