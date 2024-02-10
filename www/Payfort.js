var exec = require('cordova/exec');

exports.generateSignature = function (json, pass, success, error) {
    exec(success, error, 'Payfort', 'generateSignature', [json,pass]);
};

exports.getUdid = function (environment, success, error) {
    exec(success, error, 'Payfort', 'getUdid', [environment]);
};

exports.checkout = function (amount, command, currency, customer_email, installments, language, sdk_token, success, error) {
    exec(success, error, 'Payfort', 'checkout', [amount,command,currency,customer_email,installments,language,sdk_token]);
};
