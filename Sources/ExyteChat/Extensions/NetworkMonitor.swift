//
//  NetworkMonitor.swift
//  
//
//  Created by Alisa Mylnikova on 01.09.2023.
//

import Foundation
import Network

@MainActor
public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()

    private let networkMonitor = NWPathMonitor()
    private let workerQueue = DispatchQueue(label: "com.sonata.network.monitor")

    @Published public private(set) var isNetworkAvailable: Bool? = nil

    private init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let newStatus = path.status == .satisfied

            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isNetworkAvailable != newStatus else { return }
                self.isNetworkAvailable = newStatus
            }
        }
        networkMonitor.start(queue: workerQueue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
}
