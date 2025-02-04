//
//  RequestCaller.swift
//  RxSwiftConnect
//
//  Created by Sakon Ratanamalai on 2019/05/05.
//

import Foundation

public typealias DecodError = Decodable & ErrorInfo

enum UploadResponse<T: Decodable> {
    case progress(percentage: Double)
    case response(T)
    case rawResponse(RawResponse)
}

public class Requester: NSObject {
    
    private let baseUrl:String
    private lazy var decoder = JSONDecoder()
    private let sessionConfig:URLSessionConfiguration
    private let preventPinning:Bool
    private let hasVersion:Bool
    
    private lazy var session: URLSession = {
        let sessionPinning = SessionPinningDelegate(statusPreventPinning: preventPinning, didSendBodyData: didSendBodyData)
        let session = URLSession(configuration: .default, delegate: sessionPinning, delegateQueue: nil)
        
        return session
    }()
    
    var didSendBodyData: DidSendBodyData?
    
    public init(initBaseUrl:String,
                timeout:Int,
                isPreventPinning:Bool,
                initSessionConfig:URLSessionConfiguration,
                hasVersion:Bool = false,
                didSendBodyData: DidSendBodyData? = nil) {
        
        self.baseUrl = initBaseUrl
        //self.requester = initRequester
        self.preventPinning = isPreventPinning
        self.sessionConfig = initSessionConfig
        self.sessionConfig.timeoutIntervalForRequest = TimeInterval(timeout)
        self.hasVersion = hasVersion
        self.didSendBodyData = didSendBodyData
    }
    
    public func postQuery<DataResult:Decodable>(path:String,
                                                sendParameter:Encodable? = nil,
                                                header:[String:String]? = nil) async throws -> DataResult {
        
        
        
        let requestParameter = RequestParameter(
            httpMethod: .post,
            path: path,
            baseUrl: self.baseUrl,
            query: sendParameter?.dictionaryValue ?? nil,
            headers: header,
            hasVersion: hasVersion).asURLRequest()
        
        return try await self.call(requestParameter,config: sessionConfig,isPreventPinning: preventPinning)
        
    }
    
    public func post<DataResult:Decodable>(path:String,
                                           sendParameter:Encodable? = nil,
                                           header:[String:String]? = nil) async throws -> DataResult {
        
        
        let requestParameter = RequestParameter(
            httpMethod: .post,
            path: path,
            baseUrl: self.baseUrl,
            payload: sendParameter?.dictionaryValue ?? nil,
            headers: header,
            hasVersion: hasVersion).asURLRequest()
        
        return try await self.call(requestParameter,config: sessionConfig,isPreventPinning: preventPinning)
        
    }
    
    public func post<DataResult:Decodable>(path:String,
                                           sendParameter:Encodable? = nil,
                                           header:[String:String]? = nil,
                                           version:String) async throws -> DataResult {
        
        
        let requestParameter = RequestParameter(
            httpMethod: .post,
            path: path,
            baseUrl: self.baseUrl,
            payload: sendParameter?.dictionaryValue ?? nil,
            headers: header,
            version: version,
            hasVersion: hasVersion).asURLRequest()
        
        return  try await self.call(requestParameter,config: sessionConfig,isPreventPinning: preventPinning)
        
    }
#if canImport(UIKit)
    public func postBoundary<DataResult:Decodable>(path:String,
                                                   sendParameter:Encodable? = nil,
                                                   header:[String:String]? = nil,
                                                   dataBoundary:BoundaryCreater.DataBoundary? = nil,
                                                   version: String) async throws -> DataResult {
        
        let boundaryCreater = BoundaryCreater()
        
        var requestParameter = RequestParameter(
            httpMethod: .post,
            path: path,
            baseUrl: self.baseUrl,
            payload: nil,
            headers: header,
            version: version,
            hasVersion: hasVersion).asURLRequest()
        
        let data = boundaryCreater
            .addToBoundary(sendParameter?.dictionaryStringValue, dataBoundary: dataBoundary)
            .addEndBoundary()
            .setRequestMultipart(&requestParameter)
        
        return  try await self.callUpload(requestParameter,config: sessionConfig,isPreventPinning: preventPinning, dataUploadTask : data)
    }
#endif
    
    public func get<DataResult:Decodable>(path:String, sendParameter:Encodable? = nil) async throws -> DataResult {
        let requestParameter = RequestParameter(
            httpMethod: .get,
            path: path,
            baseUrl: self.baseUrl,
            query: sendParameter?.dictionaryValue ?? nil,
            headers: nil,
            hasVersion: hasVersion).asURLRequest()
        
        return  try await self.call(requestParameter,config: sessionConfig, isPreventPinning: preventPinning)
    }
    
    public func getRaw(path:String) async throws -> RawResponse {
        
        var requestParameter = RequestParameter(
            httpMethod: .get,
            path: path,
            baseUrl: self.baseUrl,
            payload:  nil,
            headers: nil,
            hasVersion: hasVersion).asURLRequest()
        requestParameter.url = URL(string: path)
        
        return  try await self.call(requestParameter,
                                    config: sessionConfig,
                                    isPreventPinning: preventPinning)
        
    }
    
    
    
    
    func call<DataResult:Decodable>(_ request: URLRequest,
                                    config: URLSessionConfiguration,
                                    isPreventPinning:Bool) async throws -> DataResult {
        do {
            let (data, response) = try await session.data(for: request)
            return try await self.processData(request: request, data: data, response: response)
        } catch {
            if let error = error as? NSError {
                throw CustomError(error: error)
            }
            
            throw error
        }
    }
    
    private func processData<DataResult:Decodable>(request: URLRequest, data: Data?, response: URLResponse?) async throws -> DataResult {
        
        guard let httpURLResponse = response as? HTTPURLResponse
        else { throw CustomError(unknowError: "parse HTTPURLResponse") }
        
        let statusCode =  httpURLResponse.statusCode
        
        do {
            guard let data = data
            else { throw CustomError(unknowError: "Data nil") }
            
            if statusCode == 200 {
                return try decoder.decode(DataResult.self, from: data)
            } else {
                
                let token = try request.allHTTPHeaderFields?.tryValue(forKey: "Authorize") ?? "empty"
                var customError = CustomError(responseCode: httpURLResponse.statusCode)
                
                let apiUrl = httpURLResponse.url?.absoluteString ?? ""
                let errorCode = httpURLResponse.statusCode
                let responseString = String(data: data, encoding: .utf8) ?? "-"
                let bodyString = String(data: request.httpBody ?? .init(), encoding: .utf8) ?? "-"
                
                var errorString = ""
                errorString.append("service: \(apiUrl)")
                errorString.append("\nbody: \(bodyString)")
                errorString.append("\nresponse_code: \(errorCode)")
                errorString.append("\ntoken: \(token)")
                errorString.append("\nerror: \(responseString)")
                
                customError.errorInfo = errorString
                throw customError
            }
            
        } catch {
            var customError = CustomError(responseCode: statusCode)
            
            let apiUrl = httpURLResponse.url?.absoluteString ?? ""
            let bodyString = String(data: request.httpBody ?? .init(), encoding: .utf8) ?? "-"
            let token = try request.allHTTPHeaderFields?.tryValue(forKey: "Authorize") ?? "empty"
            
            var errorString = ""
            errorString.append("service: \(apiUrl)")
            errorString.append("\nbody: \(bodyString)")
            errorString.append("\ntoken: \(token)")
            errorString.append("\nerror_decode_fail: \(error)")
            
            customError.errorInfo = errorString
            throw customError
        }
    }
    
    
    func call(_ request: URLRequest, config:URLSessionConfiguration,isPreventPinning:Bool) async throws -> RawResponse {
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse
            else { throw CustomError(unknowError: "parse HTTPURLResponse") }
            
            if httpResponse.statusCode == 200 {
                return RawResponse(statusCode: httpResponse.statusCode, data: data)
            } else {
                throw CustomError(responseCode: httpResponse.statusCode)
            }
            
        } catch {
            throw CustomError(error: error)
        }
    }
}


extension Encodable {
    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(self)
    }
    func encodeJson() -> String {
        
        do{
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: String.Encoding.utf8) ?? ""
        }
        catch{
            print("error encode \(self) to JSON ")
            return ""
        }
    }
    
    var dictionaryValue:[String: Any?]? {
        guard let data = try? JSONEncoder().encode(self),
              let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            return nil
        }
        return dictionary
    }
    
    var dictionaryStringValue:[String: String]? {
        guard let data = try? JSONEncoder().encode(self),
              let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            return nil
        }
        
        
        var dic:[String:Any] = [:]
        dictionary.forEach{
            dic.append(anotherDict: [$0.key:"\($0.value)"])
        }
        
        return dic as? [String:String]
    }
    
    
}

extension Dictionary where Key == String, Value == Any {
    
    mutating func append(anotherDict:[String:Any]) {
        for (key, value) in anotherDict {
            self.updateValue(value, forKey: key)
        }
    }
}

extension Requester{
    
    func callUpload<DataResult:Decodable>(_ request: URLRequest, config:URLSessionConfiguration,isPreventPinning:Bool, dataUploadTask:Data?) async throws -> DataResult {
        
        guard let dataUploadTask = dataUploadTask
        else { throw CustomError(unknowError: "dataUploadTask nil") }
        
        let (data, response) = try await session.upload(for: request, from: dataUploadTask)
        return try await self.processData(request: request, data: data, response: response)
    }
}



public struct DictionaryTryValueError: Error {
    public init() {}
}

public extension Dictionary {
    func tryValue(forKey key: Key, error: Error = DictionaryTryValueError()) throws -> Value {
        guard let value = self[key] else { throw error }
        return value
    }
    
}
