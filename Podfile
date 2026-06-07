# CocoaPods 依賴：MobileVLCKit 提供「支援各種格式 + 硬體解碼不卡」的播放核心。
#
# 使用步驟（在 Mac 上）：
#   1. brew install xcodegen cocoapods   # 若還沒裝
#   2. xcodegen generate                 # 產生 OneHandPlayer.xcodeproj
#   3. pod install                       # 整合 MobileVLCKit
#   4. open OneHandPlayer.xcworkspace     # 一定要開 .xcworkspace 而非 .xcodeproj
platform :ios, '15.0'

target 'OneHandPlayer' do
  use_frameworks!

  # MobileVLCKit 3.x 穩定版；想要更小體積可改用 MobileVLCKit 的精簡建置。
  pod 'MobileVLCKit', '~> 3.6.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
