var exec = require('cordova/exec');

exports.getUdid = function (environment, success, error) {
    exec(success, error, 'Payfort', 'getUdid', [environment]);
};
        
exports.checkoutWithApplePay = function (countryCode, enable3DS, visaEnabled, masterCardEnabled, amexEnabled, digitalWallet, command, merchantID, merchantReference, amount, currency, language, customerEmail, sdkToken, customerIp, paymentOption, orderDescription, customerName, phoneNumber, tokenName, settlementReference, merchantExtra, merchantExtra1, merchantExtra2, merchantExtra3, merchantExtra4, merchantExtra5, payfortMerchant, eci, accessCode,requestPhrase, madaEnabled, applePayLabel, success, error) {
    exec(success, error, 'Payfort', 'checkoutWithApplePay', [countryCode, enable3DS, visaEnabled, masterCardEnabled, amexEnabled, digitalWallet, command, merchantID, merchantReference, amount, currency, language, customerEmail, sdkToken, customerIp, paymentOption, orderDescription, customerName, phoneNumber, tokenName, settlementReference, merchantExtra, merchantExtra1, merchantExtra2, merchantExtra3, merchantExtra4, merchantExtra5, payfortMerchant, eci, accessCode, requestPhrase, madaEnabled, applePayLabel]);
};
    
exports.callPayFortForApplePay = function (environment, sdkToken, success, error) {
    exec(success, error, 'Payfort', 'callPayFortForApplePay', [environment, sdkToken]);
};
