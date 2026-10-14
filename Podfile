# Uncomment the next line to define a global platform for your project



# Matches IPHONEOS_DEPLOYMENT_TARGET in the project. The Meta mediation
# adapter refuses to resolve against anything as old as the previous 12.0,
# and pods never need to support an OS the app itself cannot install on.
platform :ios, '17.5'

target 'FlashingNumbersV1' do
  use_frameworks!
  pod 'Google-Mobile-Ads-SDK'
  pod 'GoogleMobileAdsMediationFacebook', '~> 6.21'
end

# Pod specs still declare 12.0/13.0, which current Xcode refuses to build.
# Lift every pod target to the app's own deployment target.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.5'
    end
  end
end
