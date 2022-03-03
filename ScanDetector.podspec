#
# Be sure to run `pod lib lint ScanDetector.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ScanDetector'
  s.version          = '0.1.0'
  s.summary          = '通过手机摄像头自动识别检测画面中物体的边缘四边形区域'
  s.swift_version    = '5.5.2'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  通过手机摄像头自动识别检测画面中物体的边缘四边形区域，可实现界面高度自定义，陆续提供图片拍照，编辑等功能。
                       DESC

  s.homepage         = 'https://github.com/Jack-1202/ScanDetector'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Jack-1202' => 'zhangchao901202@gmail.com' }
  s.source           = { :git => 'https://github.com/Jack-1202/ScanDetector.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = 'ScanDetector/Classes/**/*'
  
  # s.resource_bundles = {
  #   'ScanDetector' => ['ScanDetector/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
