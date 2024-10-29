//
//  ContentKeySessionDelegate.swift
//  SpatialPlayer
//
//  Created by Alvaro Velad Galvan on 24/4/24.
//

import AVFoundation

class ContentKeySessionDelegate: NSObject, AVContentKeySessionDelegate {
    var licenseURL: URL
    var certificateURL: URL
    
    enum ProgramError: Error {
        case missingApplicationCertificate
        case noCKCReturnedByKSM
    }
    
    /// URLSession for network requests
    private let urlSession = URLSession(configuration: .default)
    
    init(licenseURL: URL, certificateURL: URL) {
        self.licenseURL = licenseURL
        self.certificateURL = certificateURL
    }

    func requestApplicationCertificate() throws -> Data {
        var data: Data?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)
        
        let dataTask = self.urlSession.dataTask(with: certificateURL) {
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
    
    func requestContentKeyFromKeySecurityModule(spcData: Data, assetID: String) throws -> Data {
        var ckcData: Data? = nil
        var error: Error? = nil
        
        // Send SPC to the license service to obtain CKC
        var licenseRequest = URLRequest(url: self.licenseURL)
        licenseRequest.httpMethod = "POST"
        licenseRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-type")
        licenseRequest.httpBody = spcData

        let semaphore = DispatchSemaphore(value: 0)
        
        let dataTask = self.urlSession.dataTask(with: licenseRequest) {
            ckcData = $0
            error = $2
            semaphore.signal()
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        if ((error != nil)) {
            let errorMessage = "Failed to get CKC. Error: \(error!)"
            print(errorMessage)
            throw error!
        }
        
        guard ckcData != nil else {
            throw ProgramError.noCKCReturnedByKSM
        }
        
        return ckcData!
    }
        
    /*
     The following delegate callback gets called when the client initiates a key request or AVFoundation
     determines that the content is encrypted based on the playlist the client provided when it requests playback.
     */
    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        handleStreamingContentKeyRequest(keyRequest: keyRequest)
    }
    
    /*
     Provides the receiver with a new content key request representing a renewal of an existing content key.
     Will be invoked by an AVContentKeySession as the result of a call to -renewExpiringResponseDataForContentKeyRequest:.
     */
    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        handleStreamingContentKeyRequest(keyRequest: keyRequest)
    }
    
    /*
     Provides the receiver a content key request that should be retried because a previous content key request failed.
     Will be invoked by an AVContentKeySession when a content key request should be retried. The reason for failure of
     previous content key request is specified. The receiver can decide if it wants to request AVContentKeySession to
     retry this key request based on the reason. If the receiver returns YES, AVContentKeySession would restart the
     key request process. If the receiver returns NO or if it does not implement this delegate method, the content key
     request would fail and AVContentKeySession would let the receiver know through
     -contentKeySession:contentKeyRequest:didFailWithError:.
     */
    func contentKeySession(_ session: AVContentKeySession, shouldRetry keyRequest: AVContentKeyRequest,
                           reason retryReason: AVContentKeyRequest.RetryReason) -> Bool {
        
        var shouldRetry = false
        
        switch retryReason {
            /*
             Indicates that the content key request should be retried because the key response was not set soon enough either
             due the initial request/response was taking too long, or a lease was expiring in the meantime.
             */
        case AVContentKeyRequest.RetryReason.timedOut:
            shouldRetry = true
            
            /*
             Indicates that the content key request should be retried because a key response with expired lease was set on the
             previous content key request.
             */
        case AVContentKeyRequest.RetryReason.receivedResponseWithExpiredLease:
            shouldRetry = true
            
            /*
             Indicates that the content key request should be retried because an obsolete key response was set on the previous
             content key request.
             */
        case AVContentKeyRequest.RetryReason.receivedObsoleteContentKey:
            shouldRetry = true
            
        default:
            break
        }
        print("Should retry content key request with reason \(retryReason.rawValue), shouldRetry \(shouldRetry)")
        return shouldRetry
    }
    
    // Informs the receiver a content key request has failed.
    func contentKeySession(_ session: AVContentKeySession, contentKeyRequest keyRequest: AVContentKeyRequest, didFailWithError err: Error) {
        print("Content key request did fail with error \(err)")
    }
        
    func handleStreamingContentKeyRequest(keyRequest: AVContentKeyRequest) {
        guard let contentKeyIdentifierString = keyRequest.identifier as? String,
            let contentKeyIdentifierURL = URL(string: contentKeyIdentifierString)
        else {
            print("Failed to retrieve the assetID from the keyRequest!")
            return
        }
        let assetIDString = contentKeyIdentifierURL.getEZDRMAssetID()
        guard let assetIDData = assetIDString.data(using: .utf8)
        else {
            print("Failed to retrieve the assetID from the keyRequest!")
            return
        }

        let provideOnlinekey: () -> Void = { () -> Void in
            print("Making online streaming key request")
            do {
                let applicationCertificate = try self.requestApplicationCertificate()

                let completionHandler = { [weak self] (spcData: Data?, error: Error?) in
                    guard let strongSelf = self else { return }
                    if let error = error {
                        keyRequest.processContentKeyResponseError(error)
                        return
                    }

                    guard let spcData = spcData else { return }

                    do {
                        // Send SPC to Key Server and obtain CKC
                        let ckcData = try strongSelf.requestContentKeyFromKeySecurityModule(spcData: spcData, assetID: assetIDString)

                        /*
                         AVContentKeyResponse is used to represent the data returned from the key server when requesting a key for
                         decrypting content.
                         */
                        let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)

                        /*
                         Provide the content key response to make protected content available for processing.
                         */
                        keyRequest.processContentKeyResponse(keyResponse)
                    } catch {
                        keyRequest.processContentKeyResponseError(error)
                    }
                }

                keyRequest.makeStreamingContentKeyRequestData(forApp: applicationCertificate,
                                                              contentIdentifier: assetIDData,
                                                              options: [AVContentKeyRequestProtocolVersionsKey: [1]],
                                                              completionHandler: completionHandler)
            } catch {
                keyRequest.processContentKeyResponseError(error)
            }
        }
        
        provideOnlinekey()
    }
}

extension URL {
    func getEZDRMAssetID() -> String {
        return String(absoluteString.split(separator: ";").last ?? "")
    }
}
