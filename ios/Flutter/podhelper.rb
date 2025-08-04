require 'json'

def install_all_flutter_pods(flutter_application_path)
  install_flutter_engine_pod
  install_flutter_plugin_pods(flutter_application_path)
end

def install_flutter_engine_pod
  pod 'Flutter', :path => File.expand_path(File.join('..', '..', '.symlinks', 'flutter'))
end

def install_flutter_plugin_pods(flutter_application_path)
  plugin_manifest_path = File.join(flutter_application_path, '.flutter-plugins-dependencies')
  return unless File.exist?(plugin_manifest_path)

  plugin_manifest = JSON.parse(File.read(plugin_manifest_path))
  plugin_manifest['plugins']['ios'].each do |plugin|
    plugin_name = plugin['name']
    plugin_path = plugin['path']
    pod plugin_name, :path => File.expand_path(plugin_path, flutter_application_path)
  end
end
