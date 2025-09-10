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
#if canImport(SwiftUI)
    public func postBoundary<DataResult:Decodable>(path: String,
                                                   sendParameter: Encodable? = nil,
                                                   header: [String:String]? = nil,
                                                   dataBoundary: BoundaryCreater.DataBoundary? = nil,
                                                   version: String) async throws -> DataResult {
        return try await self.postBoundary(path: path,
                                           sendParameter: sendParameter,
                                           header: header,
                                           dataBoundaryList: [dataBoundary].compactMap{ $0 },
                                           version: version)
    }
    
    public func postBoundary<DataResult:Decodable>(path: String,
                                                   sendParameter: Encodable? = nil,
                                                   header: [String:String]? = nil,
                                                   dataBoundaryList: [BoundaryCreater.DataBoundary]? = nil,
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
            .addToBoundary(sendParameter?.dictionaryStringValue, dataBoundaryList: dataBoundaryList)
            .addEndBoundary()
            .setRequestMultipart(&requestParameter)
        
        return  try await self.callUpload(requestParameter,config: sessionConfig,isPreventPinning: preventPinning, dataUploadTask : data)
    }
#endif
    
    public func get<DataResult:Decodable>(path:String,
                                          sendParameter:Encodable? = nil,
                                          header:[String:String]? = nil,
                                          version: String = "") async throws -> DataResult {
        let requestParameter = RequestParameter(
            httpMethod: .get,
            path: path,
            baseUrl: self.baseUrl,
            query: sendParameter?.dictionaryValue ?? nil,
            headers: header,
            version: version,
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
            throw AsyncSwiftConnectError(error: error)
        }
    }
    
    private func processData<DataResult:Decodable>(request: URLRequest, data: Data?, response: URLResponse?) async throws -> DataResult {
        
        guard let httpURLResponse = response as? HTTPURLResponse
        else { throw AsyncSwiftConnectError(unknowError: "parse HTTPURLResponse") }
        
        let statusCode =  httpURLResponse.statusCode
        
        // Handle non-200 status codes first
        if statusCode != 200 {
            let jwtToken = request.allHTTPHeaderFields?.tryValue(forKey: "Authorization") ?? "empty"
            let token = request.allHTTPHeaderFields?.tryValue(forKey: "Authorize") ?? jwtToken
            var customError = AsyncSwiftConnectError(responseCode: httpURLResponse.statusCode)
            
            let apiUrl = httpURLResponse.url?.absoluteString ?? ""
            let errorCode = httpURLResponse.statusCode
            let responseString = String(data: data ?? .init(), encoding: .utf8) ?? "-"
            let bodyString = String(data: request.httpBody ?? .init(), encoding: .utf8) ?? "-"
            
            var errorString = "=========== 🚨 API Error ==========="
            errorString.append("\n📍 Endpoint: \n\(apiUrl)")
            errorString.append("\n📤 Request Body: \n\(bodyString)")
            errorString.append("\n📡 Response Code: \n\(errorCode)")
            errorString.append("\n🔐 Token: \n\(token)")
            if statusCode == 401 {
                errorString.append("\n🧠 Reason: \nUnauthorized")
            }
            
            
            customError.errorCode = String(errorCode)
            customError.errorInfo = errorString
            customError.rawResponseValue = responseString
            
            throw customError
        }
        
        do {
            return try decoder.decode(DataResult.self, from: data ?? .init())
        } catch {
            var customError = AsyncSwiftConnectError(responseCode: statusCode)
            
            let apiUrl = httpURLResponse.url?.absoluteString ?? ""
            let bodyString = String(data: request.httpBody ?? .init(), encoding: .utf8) ?? "-"
            let jwtToken = request.allHTTPHeaderFields?.tryValue(forKey: "Authorization") ?? "empty"
            let token = request.allHTTPHeaderFields?.tryValue(forKey: "Authorize") ?? jwtToken
           
            var errorString = "=========== ❗️ Decode Failed 🧨📦❓ ==========="
            errorString.append("\n📍 Endpoint: \n\(apiUrl)")
            errorString.append("\n📤 Request Body: \n\(bodyString)")
            errorString.append("\n📡 Response Code: \n\(statusCode)")
            errorString.append("\n🔐 Token: \n\(token)")
            errorString.append("\n🧠 Reason: \n\(error)")
            
            customError.errorInfo = errorString
            customError.errorCode = String(statusCode)
            customError.rawResponseValue = String(data: data ?? .init(), encoding: .utf8)
            throw customError
        }
    }
    
    
    func call(_ request: URLRequest, config:URLSessionConfiguration,isPreventPinning:Bool) async throws -> RawResponse {
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse
            else { throw AsyncSwiftConnectError(unknowError: "parse HTTPURLResponse") }
            
            if httpResponse.statusCode == 200 {
                return RawResponse(statusCode: httpResponse.statusCode, data: data)
            } else {
                throw AsyncSwiftConnectError(responseCode: httpResponse.statusCode)
            }
            
        } catch {
            throw AsyncSwiftConnectError(error: error)
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
        else { throw AsyncSwiftConnectError(unknowError: "dataUploadTask nil") }
        
        let (data, response) = try await session.upload(for: request, from: dataUploadTask)
        return try await self.processData(request: request, data: data, response: response)
    }
}



public struct DictionaryTryValueError: Error {
    public init() {}
}

public extension Dictionary {
    func tryValue(forKey key: Key, error: Error = DictionaryTryValueError()) -> Value? {
        guard let value = self[key] else { return nil}
        return value
    }
    
}
