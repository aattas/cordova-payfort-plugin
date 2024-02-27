var fs = require('fs'), path = require('path');

function getProjectName() {
    var config = fs.readFileSync('config.xml').toString();
    var parseString = require('xml2js').parseString;
    var name;
    parseString(config, function (err, result) {
        name = result.widget.name.toString();
        const r = /\B\s+|\s+\B/g;  //Removes trailing and leading spaces
        name = name.replace(r, '');
    });
    return name || null;
}

module.exports = function(context) {
	console.log("👉 context.cmdLine: " + context.cmdLine);
	var mode = 'Debug';
	if (context.cmdLine.indexOf('release') >= 0) {
	    mode = 'Release';
	}


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
    var entitlement = path.join(context.opts.projectRoot, "platforms", "ios", projectName, "Entitlements-" + mode + ".plist");
    console.log("✅ entitlement: " + entitlement);    
    if (fs.existsSync(entitlement)) {
     
      fs.readFile(entitlement, 'utf8', function (err,data) {
        
        if (err) {
          throw new Error('🚨 Unable to read entitlement: ' + err);
        }
        
        var result = data;
        var shouldBeSaved = false;

        if (!data.includes("com.apple.developer.in-app-payments")){
          shouldBeSaved = true;
          //result = data.replace(/<\/dict>\n<\/plist>/g, "\t<key>com.apple.developer.in-app-payments</key>\n\t<array>\n\t\t<string>merchant.com.outsystems</string>\n\t</array>\n</dict>\n</plist>");
          result = data.replace(/<\/dict>\n<\/plist>/g, "\t<key>com.apple.developer.in-app-payments</key>\n\t<array>\n\t\t<string>" + appleMerchantId + "</string>\n\t</array>\n</dict>\n</plist>");
        } else {
          console.log("🚨 entitlement already modified");
        }

        if (shouldBeSaved){
          fs.writeFile(entitlement, result, 'utf8', function (err) {
          if (err) 
            {throw new Error('🚨 Unable to write into entitlement: ' + err);}
          else 
            {console.log("✅ entitlement edited successfuly");}
        });
        }

      });
    } else {
        throw new Error("🚨 WARNING: entitlement was not found. The build phase may not finish successfuly");
    }
  }
