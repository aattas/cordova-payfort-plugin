//
//  Payfort.swift
//
//  Created by Andre Grillo on 09/02/2024.
//

import Foundation
import CryptoKit
import PayFortSDK
import PassKit

@objc(Payfort)
class Payfort: CDVPlugin, PKPaymentAuthorizationViewControllerDelegate {
    var currentCallbackId: String?
    var command: CDVInvokedUrlCommand?
    var payFort: PayFortController!
    var paymentCompletion: ((PKPaymentAuthorizationStatus) -> Void)?
    var payment: PKPayment!
    var paymentState = PaymentState.notStarted
    var applePayRequest: Dictionary<String, String>!
    
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
    
    private func generateSignature(parameters: [String: String], passPhrase: String) -> String? {
       
        // Step 1: Sort and concatenate parameters as per the signature pattern
        let sortedParameters = parameters.sorted { $0.key < $1.key }
        let concatenatedParams = sortedParameters.reduce("") { result, param in
            result + "\(param.key)=\(param.value)"
        }
        
        // Step 2: Add passphrase
        let stringWithPassphrase = "\(passPhrase)\(concatenatedParams)\(passPhrase)"
        
        // Step 3: Generate SHA-256 signature
        if #available(iOS 13.0, *) {
            guard let data = stringWithPassphrase.data(using: .utf8)
            else {
                return nil
            }
            let hash = SHA256.hash(data: data)
            let signature = hash.map { String(format: "%02x", $0) }.joined()
            return signature
        } else {
            return nil
        }
    }
    
    //----- New Methods -----//
    
    @objc(checkoutWithApplePay:)
    func checkoutWithApplePay(_ cdvcommand: CDVInvokedUrlCommand) {
        self.command = cdvcommand
        
        guard let paymentRequest = createPaymentRequest(cdvcommand: cdvcommand) else {
            print("Failed to create payment request")
            self.command = nil
            sendPluginResult(callbackId: cdvcommand.callbackId, status: CDVCommandStatus_ERROR, message: "Failed to create payment request")
            return
        }
        
        if let paymentAuthorizationVC = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest) {
            paymentAuthorizationVC.delegate = self
            self.viewController.present(paymentAuthorizationVC, animated: true, completion: nil)
        } else {
            print("Unable to present Apple Pay authorization")
            self.command = nil
            sendPluginResult(callbackId: cdvcommand.callbackId, status: CDVCommandStatus_ERROR, message: "Unable to present Apple Pay authorization")
        }
    }
    
    private func createPaymentRequest(cdvcommand: CDVInvokedUrlCommand) -> PKPaymentRequest? {
              
        guard cdvcommand.arguments.count >= 27,
              let countryCode = cdvcommand.arguments[0] as? String,
              let enable3DS = cdvcommand.arguments[1] as? Bool,
              let visaEnabled = cdvcommand.arguments[2] as? Bool,
              let masterCardEnabled = cdvcommand.arguments[3] as? Bool,
              let amexEnabled = cdvcommand.arguments[4] as? Bool,
              let madaEnabled = cdvcommand.arguments[31] as? Bool,
              let merchantIdentifier = cdvcommand.arguments[7] as? String,
              let amountValue = cdvcommand.arguments[9] as? Int,
              let currency = cdvcommand.arguments[10] as? String,
              let label = cdvcommand.arguments[32] as? String else {
            print("Invalid arguments")
            self.command = nil
            sendPluginResult(callbackId: cdvcommand.callbackId, status: CDVCommandStatus_ERROR, message: "Invalid arguments")
            return nil
        }

        let amount = String(amountValue)
        
        var supportedNetworks: [PKPaymentNetwork] = []
        if visaEnabled {
            supportedNetworks.append(.visa)
        }
        if masterCardEnabled {
            supportedNetworks.append(.masterCard)
        }
        if amexEnabled {
            supportedNetworks.append(.amex)
        }
        if madaEnabled {
            supportedNetworks.append(.mada)
        }
        
        let paymentRequest = PKPaymentRequest()
        
        paymentRequest.merchantIdentifier = merchantIdentifier
        paymentRequest.supportedNetworks = supportedNetworks
        paymentRequest.merchantCapabilities = enable3DS ? .capability3DS : .capabilityCredit
        paymentRequest.countryCode = countryCode
        paymentRequest.currencyCode = currency
        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(string: amount))
        ]
        
        print("paymentRequest: \(paymentRequest)")
        return paymentRequest
    }

    // MARK: PKPaymentAuthorizationViewControllerDelegate methods
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        self.paymentCompletion = completion // Store the completion handler
        self.payment = payment
        
        // Prepare the request for PayFort
        guard var request = preparePayFortRequest(from: payment, cdvcommand: self.command) else {
            //CALLBACK AQUI
            completion(.failure)
            resetClassVariables()
            return
        }
        
        if let signature = request["signature"] {
            request.removeValue(forKey: "signature")
            self.applePayRequest = request
            if let cdvcommand = self.command {
                self.sendPluginResult(callbackId: cdvcommand.callbackId, status: CDVCommandStatus_OK, message: signature)
                    return
            }
        } else {
            //CALLBACK
        }
        
    }
    
    @objc(callPayFortForApplePay:)
    func callPayFortForApplePay(_ command: CDVInvokedUrlCommand){
        
        if let environment = command.arguments[0] as? String {
            if environment == "1" {
                payFort = PayFortController(enviroment: .production)
            } else if environment == "2" {
                payFort = PayFortController(enviroment: .sandBox)
            } else {
                sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_ERROR, message: "Invalid environment arguments")
                return
            }
        } else {
            sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_ERROR, message: "Missing environment parameter")
            return
        }
        guard let sdkToken = command.arguments[1] as? String else {
            sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_ERROR, message: "Missing Token parameter")
            return
        }
        
        if var applePayRequest = self.applePayRequest {
            applePayRequest["sdk_token"] = sdkToken
            self.applePayRequest = applePayRequest
        } else {
            sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_ERROR, message: "Invalid request parameter")
            return
        }
        
        // Call PayFort SDK with the prepared request
        if let applePayPayment = self.payment {
            payFort.callPayFortForApplePay(withRequest: self.applePayRequest,
                                           applePayPayment: applePayPayment,
                                           currentViewController: self.viewController,
                                           success: { (requestDic, responseDic) in
                self.paymentState = .success
                self.sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_OK)
                if let completion = self.paymentCompletion {
                    completion(.success)
                }
                self.paymentState = .success
                self.sendPluginResult(callbackId: self.command!.callbackId, status: CDVCommandStatus_OK)
            }, faild: { (requestDic, responseDic, message) in
                self.paymentState = .failure
                self.sendPluginResult(callbackId: command.callbackId, status: CDVCommandStatus_ERROR, message: "Failed: \(message)")
                if let completion = self.paymentCompletion {
                    completion(.failure)
                }
            })
        } else {
            //CALLBACK DE FALHA!!!
        }
    }
    
    private func resetClassVariables(){
        self.command = nil
        self.paymentCompletion = nil
        self.applePayRequest = nil
        self.currentCallbackId = nil
        self.payFort = nil
        self.payment = nil
        self.paymentState = PaymentState.notStarted
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true) {
//            switch self.paymentState {
//            case .success:
//                print("✅ Payment completed successfully.")
//            case .failure:
//                print("🚨 Payment failed.")
//            case .notStarted, .userCancelled:
//                print("⚠️ Payment was canceled by the user.")
//            }
            self.resetClassVariables()
        }
    }
    
    // Helper function to prepare the PayFort request
    private func preparePayFortRequest(from payment: PKPayment, cdvcommand: CDVInvokedUrlCommand?) -> Dictionary<String, String>? {
        guard let cdvcommand = cdvcommand else { return nil }
        guard let merchantReference = cdvcommand.arguments[8] as? String,
              let amount = cdvcommand.arguments[9] as? Int,
              let currency = cdvcommand.arguments[10] as? String,
              let language = cdvcommand.arguments[11] as? String,
              let customerEmail = cdvcommand.arguments[12] as? String,
              //let sdkToken = cdvcommand.arguments[13] as? String,
              let customerIp = cdvcommand.arguments[14] as? String,
              //let paymentOption = cdvcommand.arguments[15] as? String,
              let eci = cdvcommand.arguments[28] as? String, //new
              let orderDescription = cdvcommand.arguments[16] as? String,
              let customerName = cdvcommand.arguments[17] as? String,
              let phoneNumber = cdvcommand.arguments[18] as? String,
              //let tokenName = cdvcommand.arguments[19] as? String,
              //let settlementReference = cdvcommand.arguments[20] as? String,
//              let merchantExtra = cdvcommand.arguments[21] as? String,
//              let merchantExtra1 = cdvcommand.arguments[22] as? String,
//              let merchantExtra2 = cdvcommand.arguments[23] as? String,
//              let merchantExtra3 = cdvcommand.arguments[24] as? String,
//              let merchantExtra4 = cdvcommand.arguments[25] as? String,
//              let merchantExtra5 = cdvcommand.arguments[26] as? String,
              let payfortMerchantId = cdvcommand.arguments[27] as? String, //new
              let accessCode = cdvcommand.arguments[29] as? String, //new
              let passPhrase = cdvcommand.arguments[30] as? String //new
        else { self.command = nil; return nil }
        
        var request = [String: String]()
        
        // Mandatory fields
        request["digital_wallet"] = "APPLE_PAY"
        request["command"] = "PURCHASE"
        
        //request["access_code"] = accessCode
        //request["merchant_identifier"] = payfortMerchantId
        request["merchant_reference"] = merchantReference
        request["amount"] = String(amount*100) //Multiplyer for adjusting the value to Payfort
        request["currency"] = currency
        request["language"] = language
        request["customer_email"] = customerEmail
        request["eci"] = eci
        request["order_description"] = orderDescription
        request["customer_ip"] = customerIp
        request["customer_name"] = customerName
        
        // Merchant extras
        //        request["merchant_extra"] = merchantExtra
        //        request["merchant_extra1"] = merchantExtra1
        //        request["merchant_extra2"] = merchantExtra2
        //        request["merchant_extra3"] = merchantExtra3
        //        request["merchant_extra4"] = merchantExtra4
        //        request["merchant_extra5"] = merchantExtra5
        request["phone_number"] = phoneNumber
        
        // Extract payment data from PKPayment
        if let paymentData = try? JSONSerialization.jsonObject(with: payment.token.paymentData, options: []) as? [String: Any] {
            if let data = paymentData["data"] as? String {
                request["apple_data"] = data
            }
            if let signature = paymentData["signature"] as? String {
                request["apple_signature"] = signature
            }
            if let header = paymentData["header"] as? Dictionary<String,String> {
//Payfort SDK complains about these:
//                if let transactionId = header["transactionId"] {
//                    request["apple_transactionId"] = transactionId
//                }
//                if let ephemeralPublicKey = header["ephemeralPublicKey"] {
//                    request["apple_ephemeralPublicKey"] = ephemeralPublicKey
//                }
//                if let publicKeyHash = header["publicKeyHash"] {
//                    request["apple_publicKeyHash"] = publicKeyHash
//                }
            }
            
//Apple Pay does not return these:
//            if let paymentMethod = paymentData["paymentMethod"] as? String {
//                request["apple_paymentMethod"] = paymentMethod
//            }
//            if let displayName = paymentData["displayName"] as? String {
//                request["apple_displayName"] = displayName
//            }
//            if let network = paymentData["network"] as? String {
//                request["apple_network"] = network
//            }
//            if let type = paymentData["type"] as? String {
//                request["apple_type"] = type
//            }
//            if let applicationData = paymentData["applicationData"] as? String {
//                request["apple_applicationData"] = applicationData
//            }
        } else {
            //SEND CALLBACK
            //return
        }
        
        var signatureRequest = [String:String]()
        signatureRequest["service_command"] = "SDK_TOKEN"
        signatureRequest["access_code"] = accessCode
        signatureRequest["merchant_identifier"] = payfortMerchantId
        signatureRequest["language"] = language
        payFort = PayFortController(enviroment: .sandBox)
        signatureRequest["device_id"] = payFort.getUDID()
        
        if let signature = generateSignature(parameters: signatureRequest, passPhrase: passPhrase) {
            request["signature"] = signature
        } else {
            return nil
        }
        
        return request
    }
}

enum PaymentState {
    case notStarted
    case success
    case userCancelled
    case failure
}
