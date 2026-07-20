require 'xcodeproj'
project_path = 'ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  ldflags = config.build_settings['OTHER_LDFLAGS'] || ['$(inherited)']
  ldflags = [ldflags] if ldflags.is_a?(String)
  ldflags << '-Wl,-undefined,dynamic_lookup'
  config.build_settings['OTHER_LDFLAGS'] = ldflags.uniq
end

project.save
