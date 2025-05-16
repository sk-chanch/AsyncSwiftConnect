//
//  ErrorInfo.swift
//  RxSwiftConnect
//
//  Created by Sakon Ratanamalai on 2019/05/05.
//

import Foundation

public protocol ErrorInfo: Error {
  
    var errorCode:String? { get set }
    var errorFriendlyEn:String? { get set }
    var errorFriendlyTh:String? { get set }
    var errorInfo:String? { get set }
    var error: NSError? { get set }
    var rawResponseValue: String? { get set }
    
    init(error:Error)
    init(responseCode:Int)
    init(unknowError:String)
    
}


public struct AsyncSwiftConnectError: ErrorInfo {
    public var rawResponseValue: String?
    public var errorCode: String?
    public var errorFriendlyEn: String?
    public var errorFriendlyTh: String?
    public var errorInfo: String?
    public var error: NSError?
    
    public init(error: Error) {
        self.error = error as NSError
        self.errorInfo = error.localizedDescription
    }
    
    public init(responseCode: Int) {
        self.errorCode = String(responseCode)
    }
    
    public init(unknowError: String) {
        self.errorInfo = unknowError
    }
}
