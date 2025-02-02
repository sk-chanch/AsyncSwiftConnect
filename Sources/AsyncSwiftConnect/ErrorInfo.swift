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
    
    init(error:Error)
    init(responseCode:Int)
    init(unknowError:String)
    
}


struct CustomError: ErrorInfo {
    var errorCode: String?
    var errorFriendlyEn: String?
    var errorFriendlyTh: String?
    var errorInfo: String?
    var error: NSError?
    
    init(error: Error) {
        self.error = error as NSError
        self.errorInfo = error.localizedDescription
    }
    
    init(responseCode: Int) {
        self.errorCode = String(responseCode)
        self.errorFriendlyEn = "Error with response code: \(responseCode)"
    }
    
    init(unknowError: String) {
        self.errorInfo = unknowError
    }
}
