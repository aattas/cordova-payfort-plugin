//
//  Payfort.swift
//
//  Created by Andre Grillo on 09/02/2024.
//

import Foundation
import CryptoKit

@objc
class Payfort: CDVPlugin {
    var command: CDVInvokedUrlCommand?
    
    
    @objc(initialize:)
    func initialize(_ command: CDVInvokedUrlCommand){
    }
    
    private func sendPluginResult(status: CDVCommandStatus, message: String) {
        var pluginResult = CDVPluginResult(status: status, messageAs: message)
        if let command = self.command {
            self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
        }
    }

    @objc
    func generateSignature(from jsonString: String, passphrase: String) -> String? {
        // Step 1: Parse JSON String
        guard let jsonData = jsonString.data(using: .utf8),
              let parameters = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] else {
            print("🚨 Error parsing JSON")
            return nil
        }
        
        // Step 2: Sort and concatenate parameters as per the signature pattern
        let sortedParameters = parameters.sorted { $0.key < $1.key }
        let concatenatedParams = sortedParameters.reduce("") { result, param in
            result + "\(param.key)=\(param.value)"
        }
        
        // Step 3: Add passphrase
        let stringWithPassphrase = "\(passphrase)\(concatenatedParams)\(passphrase)"
        
        // Step 4: Generate SHA-256 signature
        if #available(iOS 13.0, *) {
            guard let data = stringWithPassphrase.data(using: .utf8) else { return nil }
            let hash = SHA256.hash(data: data)
            return hash.map { String(format: "%02x", $0) }.joined()
        } else {
            return nil
        }
    }
}
