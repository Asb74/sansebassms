Pod::Spec.new do |s|
  s.name             = 'Flutter'
  s.version          = '1.0.0'
  s.summary          = 'Flutter Framework'
  s.description      = <<-DESC
                       Flutter engine dynamic framework
                       DESC
  s.homepage         = 'https://flutter.dev'
  s.license          = { :type => 'BSD' }
  s.author           = { 'Flutter Dev Team' => 'flutter-dev@googlegroups.com' }
  s.source           = { :path => '.' }

  s.ios.vendored_frameworks = 'App.framework', 'Flutter.framework'
  s.frameworks = 'UIKit', 'Foundation', 'AVFoundation', 'CoreGraphics', 'CoreMedia', 'CoreVideo'
  s.libraries = 'c++', 'z', 'sqlite3'

  s.platform = :ios, '11.0'
end
