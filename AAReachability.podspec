#
# Be sure to run `pod lib lint AAReachability.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AAReachability'
  s.version          = '1.0.0'
  s.summary          = 'iOS reachability tool that support 5G'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

#  s.description      = <<-DESC
#    "支持5G识别的网络状态监听工具"
#                       DESC

  s.homepage         = 'https://github.com/Fxxxxxx/AAReachability'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'AaronFeng' => 'aaronfeng1993@163.com' }
  s.source           = { :git => 'https://github.com/Fxxxxxx/AAReachability.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = 'AAReachability/Classes/**/*'
  
  # s.resource_bundles = {
  #   'AAReachability' => ['AAReachability/Assets/*.png']
  # }

  s.public_header_files = ['AAReachability/Classes/**/AAReachability.h']
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
