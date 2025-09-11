//
//  Responder.swift
//  AsyncSwiftConnect
//
//  Created by MK-Mini on 11/9/2568 BE.
//

import Foundation

struct Responder {
    
    func processData<DataResult:Decodable>(request: URLRequest, data: Data?, response: URLResponse?) throws -> DataResult {
        
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
            let decoder = JSONDecoder()
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
}
