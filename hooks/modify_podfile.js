const fs = require('fs-extra');
const path = require('path');
const Q = require('q');
var child_process = require('child_process');

module.exports = function(context) {
    const deferred = Q.defer();
    const iosPlatformPath = path.join(context.opts.projectRoot, 'platforms/ios');
    const podfilePath = path.join(iosPlatformPath, 'Podfile');

    const postInstallScript = `
post_install do |installer|
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
            console.log(err);
            deferred.reject(err);
        } else {
            if (data.indexOf('post_install') === -1) { // Checks if post_install hook is not already added
                fs.appendFile(podfilePath, postInstallScript, 'utf8', function(err) {
                    if (err) {
                        console.log(err);
                        deferred.reject(err);
                    } else {
                        //Run "pod install"
                        var pathiOS = path.join(context.opts.projectRoot,"platforms","ios");
                        try {
                            child_process.execSync('pod install', {cwd: pathiOS});
                            console.log("⭐️ Pod Install: Process finished ⭐️");
                            deferred.resolve();
                        } catch (error) {
                            console.log("🚨 ERROR: ", error);
                            deferred.reject(error);
                        }
                    }
                });
            } else {
                deferred.resolve();
            }
        }
    });

    return deferred.promise;
};
