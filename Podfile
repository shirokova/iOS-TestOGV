
# -------- Pods init

# Disable all warnings in pods so the build is clean
inhibit_all_warnings!

# Define CP Specs source
source 'https://github.com/CocoaPods/Specs.git'

# Force iOS8+ platform
platform :ios, '8.3'

# Swift frameworks
use_frameworks!


# -------- Frameworks / Networking

pod 'Alamofire'


# -------- OGVKit

source 'https://github.com/CocoaPods/Specs.git'

# This line is needed until OGVKit is fully published to CocoaPods
# Remove once packages published:
source 'https://github.com/brion/OGVKit-Specs.git'

#target 'testOGV' do
    pod "OGVKit"
#end

# hack for missing resource bundle on iPad builds
# https://github.com/CocoaPods/CocoaPods/issues/2292
# Remove once bug fixed is better:
post_install do |installer|
    if installer.respond_to?(:project)
        project = installer.project
        else
        project = installer.pods_project
    end
    project.targets.each do |target|
        if target.product_reference.name == 'OGVKitResources.bundle' then
            target.build_configurations.each do |config|
                config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2' # iPhone, iPad
            end
        end
    end
end