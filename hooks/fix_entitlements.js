var fs = require('fs'), path = require('path');

function getProjectName() {
    var config = fs.readFileSync('config.xml').toString();
    var parseString = require('xml2js').parseString;
    var name;
    parseString(config, function (err, result) {
        if (err) throw new Error("Failed to parse config.xml");
        name = result.widget.name.toString();
        const r = /\B\s+|\s+\B/g;  //Removes trailing and leading spaces
        name = name.replace(r, '');
    });
    return name || null;
}

function modifyEntitlementFile(filePath, appleMerchantId) {
    if (fs.existsSync(filePath)) {
        fs.readFile(filePath, 'utf8', function (err, data) {
            if (err) {
                throw new Error('🚨 Unable to read file: ' + filePath + ' Error: ' + err);
            }
            var result = data;
            var shouldBeSaved = false;

            if (!data.includes("com.apple.developer.in-app-payments")) {
                shouldBeSaved = true;
                result = data.replace(/<\/dict>\n<\/plist>/g, "\t<key>com.apple.developer.in-app-payments</key>\n\t<array>\n\t\t<string>" + appleMerchantId + "</string>\n\t</array>\n</dict>\n</plist>");
            } else {
                console.log("🚨 File already modified: " + filePath);
            }

            if (shouldBeSaved) {
                fs.writeFile(filePath, result, 'utf8', function (err) {
                    if (err) {
                        throw new Error('🚨 Unable to write into file: ' + filePath + ' Error: ' + err);
                    } else {
                        console.log("✅ File edited successfully: " + filePath);
                    }
                });
            }
        });
    } else {
        throw new Error("🚨 WARNING: File was not found: " + filePath + ". The build phase may not finish successfully");
    }
}

module.exports = function(context) {
    const args = process.argv
    var appleMerchantId;
    for (const arg of args) {  
      if (arg.includes('APPLE_MERCHANT_ID')){
        var stringArray = arg.split("=");
        appleMerchantId = stringArray.slice(-1).pop();
      }
    }

    console.log("⭐️ APPLE_MERCHANT_ID: " + appleMerchantId);
    var projectName = getProjectName();
    var entitlementDebug = path.join(context.opts.projectRoot, "platforms", "ios", projectName, "Entitlements-Debug.plist");
    var entitlementRelease = path.join(context.opts.projectRoot, "platforms", "ios", projectName, "Entitlements-Release.plist");
    
    console.log("✅ entitlementDebug: " + entitlementDebug); 
    console.log("✅ entitlementRelease: " + entitlementRelease);    
    
    modifyEntitlementFile(entitlementDebug, appleMerchantId);
    modifyEntitlementFile(entitlementRelease, appleMerchantId);
}
