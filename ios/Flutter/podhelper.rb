require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), Dir.pwd)

flutter_root = File.expand_path('..', Dir.pwd)
flutter_application_path = File.expand_path('..', __dir__)

flutter_install_all_ios_pods(flutter_application_path)
