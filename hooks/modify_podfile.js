const fs = require('fs');
const path = require('path');

module.exports = function(context) {
    const iosPlatformPath = path.join(context.opts.projectRoot, 'platforms/ios');
    const podfilePath = path.join(iosPlatformPath, 'Podfile');

    const postInstallScript = `
\\npost_install do |installer|
  installer.pods_project.targets.each do |target|
    if ['PayFortSDK'].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      end
    end
  end
end
`;

    fs.readFile(podfilePath, 'utf8', function(err, data) {
        if (err) {
            return console.log(err);
        }
        if (data.indexOf('post_install') === -1) { // Check if post_install hook is not already added
            fs.appendFile(podfilePath, postInstallScript, 'utf8', function(err) {
                if (err) return console.log(err);
            });
        }
    });
};
