//
//  Payfort.swift
//
//  Created by Andre Grillo on 09/02/2024.
//

import Foundation
import CryptoKit
import PayFortSDK

@objc
class Payfort: CDVPlugin {
    var command: CDVInvokedUrlCommand?
    
    @objc(initialize:)
    func initialize(_ command: CDVInvokedUrlCommand){
    }
    
    private func sendPluginResult(callbackId: String, status: CDVCommandStatus, message: String = "") {
        let pluginResult = CDVPluginResult(status: status, messageAs: message)
        self.commandDelegate!.send(pluginResult, callbackId: callbackId)
    }
    
    @objc(getUdid:)
    func getUdid(_ command: CDVInvokedUrlCommand){
        var payFort: PayFortController!
        
        if let environment = command.arguments[0] as? String {
            if environment == "production" {
                payFort = PayFortController(enviroment: .production)
            } else if environment == "development" {
                payFort = PayFortController(enviroment: .sandBox)
            } else {
                sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_ERROR, message: "Invalid arguments")
                return
            }
        } else {
            sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_ERROR, message: "Invalid arguments")
            return
        }
        let udid = payFort.getUDID()
        sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_OK, message: udid)
    }

    @objc(generateSignature:)
    func generateSignature(_ command: CDVInvokedUrlCommand) {
        guard command.arguments.count >= 2,
              let jsonString = command.arguments[0] as? String,
              let passphrase = command.arguments[1] as? String else {
            sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_ERROR, message: "Invalid arguments")
            return
        }
        // Step 1: Parse JSON String
        guard let jsonData = jsonString.data(using: .utf8),
              let parameters = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] else {
            print("🚨 Error parsing JSON")
            sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_OK, message: "Error parsing JSON")
            return
        }
        
        // Step 2: Sort and concatenate parameters as per the signature pattern
        let sortedParameters = parameters.sorted { $0.key < $1.key }
        let concatenatedParams = sortedParameters.reduce("") { result, param in
            result + "\(param.key)=\(param.value)"
        }
        print("⭐️ concatenatedParams: \(concatenatedParams)")
        
        // Step 3: Add passphrase
        let stringWithPassphrase = "\(passphrase)\(concatenatedParams)\(passphrase)"
        print("⭐️ stringWithPassphrase: \(stringWithPassphrase)")
        
        // Step 4: Generate SHA-256 signature
        if #available(iOS 13.0, *) {
            guard let data = stringWithPassphrase.data(using: .utf8)
            else {
                sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_ERROR, message: "Error generating signature")
                return
            }
            let hash = SHA256.hash(data: data)
            print("⭐️ Signature: " + hash.map { String(format: "%02x", $0) }.joined())
            sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_OK, message: hash.map { String(format: "%02x", $0) }.joined())
        } else {
            sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_ERROR, message: "Error generating signature")
        }
    }
}
