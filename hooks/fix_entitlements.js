/* fix_entitlements.js — supports multiple APPLE_MERCHANT_ID* variables and merges them into the entitlement array */

var fs = require("fs");
var path = require("path");

function getProjectName() {
  var config = fs.readFileSync("config.xml").toString();
  var parseString = require("xml2js").parseString;
  var name;
  parseString(config, function (err, result) {
    if (err) throw new Error("Failed to parse config.xml");
    name = result.widget.name.toString();
    // remove leading/trailing/inner stray spaces like original
    name = name.replace(/\B\s+|\s+\B/g, "");
  });
  return name || null;
}

function unique(list) {
  return Array.from(new Set(list.filter(Boolean)));
}

function toMerchantList(raw) {
  if (!raw) return [];
  return String(raw)
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function collectMerchantIdsFromArgs(argv) {
  // Accept APPLE_MERCHANT_ID and also APPLE_MERCHANT_ID2/3/…
  // Allow csv in any of them, e.g. APPLE_MERCHANT_ID="merchant.a,merchant.b"
  let all = [];
  for (const arg of argv) {
    if (arg.startsWith("APPLE_MERCHANT_ID")) {
      const parts = arg.split("=");
      const value = parts.slice(1).join("="); // in case value also contains '='
      all = all.concat(toMerchantList(value));
    }
  }
  return unique(all);
}

function ensureEntitlementsHasMerchants(plistContent, merchants) {
  // Inject or merge into:
  // <key>com.apple.developer.in-app-payments</key>
  // <array> ... <string>merchant.com.foo</string> ... </array>
  const key = "com.apple.developer.in-app-payments";
  const keyRe =
    /<key>com\.apple\.developer\.in-app-payments<\/key>\s*<array>([\s\S]*?)<\/array>/m;

  let changed = false;
  if (!keyRe.test(plistContent)) {
    // Create a fresh block with all merchants before </dict></plist>
    const merchantsXml = merchants
      .map((id) => `\t\t<string>${id}</string>`)
      .join("\n");
    const block =
      `\t<key>${key}</key>\n\t<array>\n` + merchantsXml + `\n\t</array>\n`;
    const out = plistContent.replace(
      /<\/dict>\s*<\/plist>\s*$/m,
      block + `</dict>\n</plist>`
    );
    return { content: out, changed: true };
  }

  // Merge into existing array; avoid duplicates
  const out = plistContent.replace(keyRe, (match, inner) => {
    let updatedInner = inner;
    merchants.forEach((id) => {
      const idRe = new RegExp(
        `<string>\\s*${id.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*<\\/string>`,
        "m"
      );
      if (!idRe.test(updatedInner)) {
        updatedInner = `${updatedInner}\n\t\t<string>${id}</string>`;
        changed = true;
      }
    });
    return `<key>${key}</key>\n\t<array>${updatedInner}\n\t</array>`;
  });

  return { content: out, changed };
}

function modifyEntitlementFile(filePath, merchantIds) {
  if (!fs.existsSync(filePath)) {
    throw new Error(
      "🚨 WARNING: File not found: " +
        filePath +
        ". The build phase may not finish successfully"
    );
  }

  const data = fs.readFileSync(filePath, "utf8");
  const { content, changed } = ensureEntitlementsHasMerchants(data, merchantIds);

  if (changed) {
    fs.writeFileSync(filePath, content, "utf8");
    console.log("✅ Entitlements updated:", filePath);
  } else {
    console.log("ℹ️ No entitlement changes needed:", filePath);
  }
}

module.exports = function (context) {
  const argv = process.argv || [];
  const merchantIds = collectMerchantIdsFromArgs(argv);

  if (!merchantIds.length) {
    throw new Error(
      "🚨 No APPLE_MERCHANT_ID variables supplied. Pass at least one variable (e.g. APPLE_MERCHANT_ID=merchant.com.yourid)."
    );
  }

  console.log("⭐️ Apple Pay merchant IDs:", merchantIds);

  const projectName = getProjectName();
  const entitlementDebug = path.join(
    context.opts.projectRoot,
    "platforms",
    "ios",
    projectName,
    "Entitlements-Debug.plist"
  );
  const entitlementRelease = path.join(
    context.opts.projectRoot,
    "platforms",
    "ios",
    projectName,
    "Entitlements-Release.plist"
  );

  console.log("✅ entitlementDebug:", entitlementDebug);
  console.log("✅ entitlementRelease:", entitlementRelease);

  modifyEntitlementFile(entitlementDebug, merchantIds);
  modifyEntitlementFile(entitlementRelease, merchantIds);
};
