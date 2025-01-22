//
//  CryptoResourceLoaderDelegate.swift
//  Chat
//
//  Created by Boris on 15.01.2025.
//

import AVFoundation
import CryptoKit

public class CryptoResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    private let url: URL
    private let key: Data
    private let iv: Data
    
    public lazy var localStreamingURL: URL = {
        guard !key.isEmpty && !iv.isEmpty else { return url }
        guard var components = URLComponents(url: self.url, resolvingAgainstBaseURL: false) else { fatalError() }
        components.scheme = "crypto"
        guard let retURL = components.url else { fatalError() }
        return retURL
    }()
    
    public init(url: URL, key: Data, iv: Data) {
        self.url = url
        self.key = key
        self.iv = iv
    }
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard loadingRequest.request.url != nil else { return false }
        
        do {
            let encryptedData = try Data(contentsOf: self.url)
            guard let decryptedData = decrypt(encryptedData, key: key, iv: iv) else {
                loadingRequest.finishLoading(with: ResourceLoaderError.decryptionError)
                return false
            }
            
            if let contentInformationRequest = loadingRequest.contentInformationRequest {
                contentInformationRequest.contentType = AVFileType.mp4.rawValue
                contentInformationRequest.contentLength = Int64(decryptedData.count)
                contentInformationRequest.isByteRangeAccessSupported = true
            }
            
            if let dataRequest = loadingRequest.dataRequest {
                let requestedOffset = Int(dataRequest.requestedOffset)
                let requestedLength = dataRequest.requestedLength
                let startIndex = max(0, requestedOffset)
                let endIndex = min(decryptedData.count, startIndex + requestedLength)

                if startIndex < endIndex {
                    let dataChunk = decryptedData.subdata(in: startIndex..<endIndex)
                    dataRequest.respond(with: dataChunk)
                    loadingRequest.finishLoading()
                } else {
                    loadingRequest.finishLoading(with: ResourceLoaderError.decryptionError)
                }
            }
            return true
        } catch {
            loadingRequest.finishLoading(with: error)
            return false
        }
    }
    
    private func decrypt(_ data: Data, key: Data, iv: Data) -> Data? {
        let combined = NSMutableData()
        combined.append(iv)
        combined.append(data)
        return decryptGCM(key: key, encryptedContent: combined as Data)
    }
    
    private func decryptGCM (key: Data, encryptedContent:Data) -> Data? {
        do {
            let sealedBoxToOpen = try AES.GCM.SealedBox(combined: encryptedContent)
            let gcmKey = SymmetricKey.init(data: key)
            let decryptedData = try AES.GCM.open(sealedBoxToOpen, using: gcmKey)
            return decryptedData
        } catch {
            return nil;
        }
    }
}

extension CryptoResourceLoaderDelegate {
    enum ResourceLoaderError: Error {
        case decryptionError
    }
}
