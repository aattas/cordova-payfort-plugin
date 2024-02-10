//
//  Payfort.swift
//
//  Created by Andre Grillo on 09/02/2024.
//

import Foundation
import CryptoKit
import PayFortSDK

@objc(Payfort)
class Payfort: CDVPlugin {
    var command: CDVInvokedUrlCommand?
    var payFort: PayFortController!
    
    @objc(initialize:)
    func initialize(_ command: CDVInvokedUrlCommand){
    }
    
    private func sendPluginResult(callbackId: String, status: CDVCommandStatus, message: String = "") {
        let pluginResult = CDVPluginResult(status: status, messageAs: message)
        self.commandDelegate!.send(pluginResult, callbackId: callbackId)
    }
    
    @objc(getUdid:)
    func getUdid(_ command: CDVInvokedUrlCommand){
        
        if let environment = command.arguments[0] as? String {
            if environment == "1" {
                payFort = PayFortController(enviroment: .production)
            } else if environment == "2" {
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
    
    @objc(checkout:)
    func checkout(_ cdvcommand: CDVInvokedUrlCommand){
        
        if let amount = cdvcommand.arguments[0] as? String,
           let command = cdvcommand.arguments[1] as? String,
           let currency = cdvcommand.arguments[2] as? String,
           let customer_email = cdvcommand.arguments[3] as? String,
           let installments = cdvcommand.arguments[4] as? String,
           let language = cdvcommand.arguments[5] as? String,
           let sdk_token = cdvcommand.arguments[6] as? String {
            
           let request = ["amount" : amount,
               "command" : command,
               "currency" : currency,
               "customer_email" : customer_email,
               "installments" : installments,
               "language" : language,
               "sdk_token" : sdk_token]
            
            //        let request = ["amount" : "1000",
            //            "command" : "AUTHORIZATION",
            //            "currency" : "AED",
            //            "customer_email" : "rzghebrah@payfort.com",
            //            "installments" : "",
            //            "language" : "en",
            //            "sdk_token" : "token"]
            
            payFort.callPayFort(withRequest: request, currentViewController: self.viewController, success: { (requestDic, responseDic) in
                        print("✅ success")
                self.sendPluginResult(callbackId: cdvcommand.callbackId, status: CDVCommandStatus_OK)
                    },
                    canceled: { (requestDic, responseDic) in
                        print("🚨 canceled")
                self.sendPluginResult(callbackId: cdvcommand.callbackId, status: CDVCommandStatus_ERROR, message: "Cancelled")
                    },
                    faild: { (requestDic, responseDic, message) in
                        print("🚨 failed")
                self.sendPluginResult(callbackId: cdvcommand.callbackId, status: CDVCommandStatus_ERROR, message: "Failed")
            })
            
        }
    }
}
