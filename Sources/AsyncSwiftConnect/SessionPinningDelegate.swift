//
//  SessionPinningDelegate.swift
//  RxSwiftConnect
//
//  Created by Sakon Ratanamalai on 2019/05/05.
//

import Foundation
import Security
import CryptoKit

public typealias DidSendBodyData =  ((_ task: URLSessionTask,
                                     _ bytesSent: Int64,
                                     _ totalBytesSent: Int64,
                                     _ totalBytesExpectedToSend: Int64)->())

public final class SessionPinningDelegate: NSObject, URLSessionDelegate {
    
    let didSendBodyData: DidSendBodyData?
    
    // Hash of Public Key (SHA-256 Base64 String)
    private let pinnedPublicKeys: [String]
    
    // Standard Header Public Key (Because SecKeyCopyExternalRepresentation iOS drop Header)
    private let rsa2048Asn1Header: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ]
    
    private let ecdsaSecp256r1Asn1Header: [UInt8] = [
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02,
        0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
        0x42, 0x00
    ]
    
    public init(
        pinnedPublicKeys: [String]
    ){
        self.pinnedPublicKeys = pinnedPublicKeys
        self.didSendBodyData = nil
    }
    
    public init(
        pinnedPublicKeys: [String],
        didSendBodyData: DidSendBodyData?
    ){
        self.didSendBodyData = didSendBodyData
        self.pinnedPublicKeys = pinnedPublicKeys
    }
    
    public func urlSession(_ session: URLSession,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        
        guard pinnedPublicKeys.isEmpty == false else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        var secresult: CFError?
        let status = SecTrustEvaluateWithError(serverTrust, &secresult)
        
        guard status else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // 1. Count Certificate all in Chain (Leaf + Intermediate + Root)
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        var isPinned = false
        
        // 2. For loop Certificate one by one
        for i in 0..<certificateCount {
            guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, i),
                  let serverPublicKey = SecCertificateCopyKey(serverCertificate) else {
                continue
            }
            
            // Fetch Data of Public Key
            var error: Unmanaged<CFError>?
            guard let serverPublicKeyData = SecKeyCopyExternalRepresentation(serverPublicKey, &error) as Data? else {
                continue
            }
            
            // Create Data by use Header concat with Public Key Data
            var rsaData = Data(rsa2048Asn1Header)
            rsaData.append(serverPublicKeyData)
            
            var ecdsaData = Data(ecdsaSecp256r1Asn1Header)
            ecdsaData.append(serverPublicKeyData)
            
            // Hash Data with SHA-256
            let rsaHashBase64 = Data(SHA256.hash(data: rsaData)).base64EncodedString()
            let ecdsaHashBase64 = Data(SHA256.hash(data: ecdsaData)).base64EncodedString()
            
            // Compare Hash with Pinned Keys
            if pinnedPublicKeys.contains(rsaHashBase64) || pinnedPublicKeys.contains(ecdsaHashBase64) {
                // if matched with any pinned key, consider it pinned
                isPinned = true
                break
            }
            
        }
        
        guard isPinned else {
            // Pinning failed
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Trust Public Key Hash
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

extension SessionPinningDelegate: URLSessionTaskDelegate {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        didSendBodyData?(task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
    }
}
