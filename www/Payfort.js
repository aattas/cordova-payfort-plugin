var exec = require('cordova/exec');

exports.generateSignature = function (json, pass, success, error) {
    exec(success, error, 'Payfort', 'generateSignature', [json,pass]);
};
