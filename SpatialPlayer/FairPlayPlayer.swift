//
//  FairPlayPlayer.swift
//  SpatialPlayer
//
//  Created by Alvaro Velad Galvan on 15/4/24.
//

import Foundation
import AVFoundation

class FairPlayPlayer: NSObject, AVContentKeySessionDelegate {
    
    /// The currently loaded video.
    private(set) var currentItem: PlayerViewModel? = nil
    
    /// AVContentKeySession for handling content key requests
    private var contentKeySession: AVContentKeySession!
    
    /// URLSession for network requests
    private let urlSession = URLSession(configuration: .default)
    
    func getAsset(with video: PlayerViewModel) -> AVURLAsset {
        currentItem = video
        let asset = AVURLAsset(url: video.videoURL!)
        if (video.certificateURL != nil && video.licenseURL != nil) {
            // Create the Content Key Session using the FairPlay Streaming key system.
            contentKeySession = AVContentKeySession(keySystem: .fairPlayStreaming)
            contentKeySession.setDelegate(self, queue: DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).ContentKeyDelegateQueue"))
            contentKeySession.addContentKeyRecipient(asset)
        }
        return asset
    }
    
    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        // Extract content identifier and license service URL from the key request
        guard let contentKeyIdentifierString = keyRequest.identifier as? String,
            let contentIdentifier = contentKeyIdentifierString.replacingOccurrences(of: "skd://", with: "") as String?,
            let contentIdentifierData = contentIdentifier.data(using: .utf8)
        else {
            print("ERROR: Failed to retrieve the content identifier from the key request!")
            return
        }
        
        // Completion handler for making streaming content key request
        let handleCkcAndMakeContentAvailable = { [weak self] (spcData: Data?, error: Error?) in
            guard self != nil else { return }
            
            if let error = error {
                print("ERROR: Failed to prepare SPC: \(error.localizedDescription)")
                // Report SPC preparation error to AVFoundation
                keyRequest.processContentKeyResponseError(error)
                return
            }
            
            guard let spcData = spcData else { return }
            
            // Send SPC to the license service to obtain CKC
            var licenseRequest = URLRequest(url: (self!.currentItem?.licenseURL)!)
            licenseRequest.httpMethod = "POST"
            licenseRequest.httpBody = spcData
            
            var dataTask: URLSessionDataTask?
            
            dataTask = self!.urlSession.dataTask(with: licenseRequest, completionHandler: { (data, response, error) in
                defer {
                    dataTask = nil
                }
                
                if let error = error {
                    print("ERROR: Failed to get CKC: \(error.localizedDescription)")
                } else if
                    let ckcData = data,
                    let response = response as? HTTPURLResponse,
                    response.statusCode == 200 {
                    // Create AVContentKeyResponse from CKC data
                    let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
                    // Provide the content key response to make protected content available for processing
                    keyRequest.processContentKeyResponse(keyResponse)
                }
            })
            
            dataTask?.resume()
        }
        
        do {
            // Request the application certificate for the content key request
            let applicationCertificate = try requestApplicationCertificate()
            
            // Make the streaming content key request with the specified options
            keyRequest.makeStreamingContentKeyRequestData(
                forApp: applicationCertificate,
                contentIdentifier: contentIdentifierData,
                options: [AVContentKeyRequestProtocolVersionsKey: [1]],
                completionHandler: handleCkcAndMakeContentAvailable
            )
        } catch {
            // Report error in processing content key response
            keyRequest.processContentKeyResponseError(error)
        }
    }
    
    /*
     Requests the Application Certificate.
    */
    func requestApplicationCertificate() throws -> Data {
        var data: Data?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        let dataTask = self.urlSession.dataTask(with: (currentItem?.certificateURL)!) {
            data = $0
            error = $2
            semaphore.signal()
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)
        
        if ((error != nil)) {
            // Handle any errors that occur while loading the certificate.
            let errorMessage = "Failed to load the FairPlay application certificate. Error: \(error!)"
            print(errorMessage)
            throw error!
        }
        
        return data!
    }
}
