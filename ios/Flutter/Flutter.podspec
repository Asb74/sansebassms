Pod::Spec.new do |s|
  s.name             = 'Flutter'
  s.version          = '1.0.0'
  s.summary          = 'Flutter engine framework'
  s.description      = <<-DESC
                       Flutter engine framework for iOS
                       DESC
  s.homepage         = 'https://flutter.dev'
  s.license          = { :type => 'BSD' }
  s.author           = { 'Flutter Dev Team' => 'flutter-dev@googlegroups.com' }
  s.source           = { :http => 'https://storage.googleapis.com/flutter_infra_release/flutter' }

  s.ios.vendored_frameworks = 'Flutter.framework'
  s.platform = :ios, '11.0'
end
