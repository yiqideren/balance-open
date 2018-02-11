//
//  PoloniexAPI2.swift
//  Balance
//
//  Created by Benjamin Baron on 1/22/18.
//  Copyright © 2018 Balanced Software, Inc. All rights reserved.
//

import Foundation

// This is for example Poloniex
class PoloniexAPI2: AbstractApi {
    override var requestMethod: ApiRequestMethod { return .post }
    override var requestDataFormat: ApiRequestDataFormat { return .urlEncoded }
    override var requestEncoding: ApiRequestEncoding { return .simpleHmacSha512 }
    override var responseHandler: ResponseHandler? { return self }
    
    //MARK: Builder methods for Request
    override func createRequest(for action: APIAction) -> URLRequest? {
        switch action.type {
        case .accounts, .transactions:
            let message = createMessage(for: action)
            guard let messageSigned = generateMessageSigned(for: action), let url = action.url else {
                return nil
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = requestMethod.rawValue
            request.setValue(action.credentials.apiKey, forHTTPHeaderField: "Key")
            request.setValue(messageSigned, forHTTPHeaderField: "Sign")
            request.httpBody = message?.data(using: .utf8)
            
            return request
        }
    }
    
    override func createMessage(for action: APIAction) -> String? {
        return action.components?.query
    }
    
    override func processApiErrors(from data: Data) -> Error? {
        if let dict = createDict(from: data), let errorDict = dict["error"] as? String {
            return ExchangeBaseError.other(message: errorDict)
        }
        
        return nil
    }
    
    override func buildTransactions(from data: Data) -> Any {
        guard let rawData = try? JSONSerialization.jsonObject(with: data, options: []),
            let json = rawData as? [String : AnyObject] else {
                return []
        }
        
        var transactions = [NewPoloniexTransaction]()
        
        if let depositsJSON = json["deposits"] as? [[String : Any]],
            let serialized = try? JSONSerialization.data(withJSONObject: depositsJSON, options: .prettyPrinted),
            let deposits = try? JSONDecoder().decode([NewPoloniexTransaction].self, from: serialized) {
            
            deposits.forEach { $0.type = "deposit" }
            transactions += deposits
            
        }
        
        if let withdrawalsJSON = json["withdrawals"] as? [[String : Any]],
            let serialized = try? JSONSerialization.data(withJSONObject: withdrawalsJSON, options: .prettyPrinted),
            let withdrawals = try? JSONDecoder().decode([NewPoloniexTransaction].self, from: serialized) {
            
            withdrawals.forEach { $0.type = "withdrawal" }
            transactions += withdrawals
            
        }
        
        return transactions
    }
    
    
    override func buildAccounts(from data: Data) -> Any {
        guard let data = prepareAccountsData(from: data),
            let accounts = try? JSONDecoder().decode([NewPoloniexAccount].self, from: data) else {
                return []
        }
        
        return accounts
    }
    
}

extension PoloniexAPI2: ResponseHandler {
    func handleResponseData(for action: APIAction?, data: Data?, error: Error?, urlResponse: URLResponse?) -> Any {
        guard let action = action else {
            return ExchangeBaseError.other(message: "No action provided")
        }

        if let error = processErrors(response: urlResponse, data: data, error: error) {
            return error
        }
        
        return processData(requestType: action.type, data: data)
    }
}

private extension PoloniexAPI2 {
    func prepareAccountsData(from data: Data) -> Data? {
        guard let rawData = try? JSONSerialization.jsonObject(with: data),
            let dict = rawData as? [String: AnyObject] else {
            return nil
        }
        
        let flatDict = dict.map { (key, value) -> [String : AnyObject] in
            if var dict = value as? [String: AnyObject] {
                dict["currency"] = key as AnyObject
                return dict
            }
            return [:]
        }
        
        return try? JSONSerialization.data(withJSONObject: flatDict, options: .prettyPrinted)
    }
}
