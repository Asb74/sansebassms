require 'json'

def flutter_install_all_ios_pods(flutter_application_path)
  install_flutter_engine_pod
  install_flutter_plugin_pods(flutter_application_path)
end

def install_flutter_engine_pod
  flutter_root = ENV['FLUTTER_ROOT']
  pod 'Flutter', :path => File.join(flutter_root, 'bin', 'cache', 'artifacts', 'engine', 'ios')
end

def install_flutter_plugin_pods(flutter_application_path)
  plugin_manifest_path = File.join(flutter_application_path, '.flutter-plugins-dependencies')
  return unless File.exist?(plugin_manifest_path)

  plugin_manifest = JSON.parse(File.read(plugin_manifest_path))
  plugin_manifest['plugins']['ios'].each do |plugin|
    plugin_name = plugin['name']
    plugin_path = plugin['path']
    pod plugin_name, :path => plugin_path
  end
end
