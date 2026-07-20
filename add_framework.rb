require 'xcodeproj'
project_path = 'ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add OTHER_LDFLAGS
target.build_configurations.each do |config|
  ldflags = config.build_settings['OTHER_LDFLAGS'] || ['$(inherited)']
  ldflags = [ldflags] if ldflags.is_a?(String)
  ldflags << '-weak_framework'
  ldflags << 'CoreAudioTypes'
  config.build_settings['OTHER_LDFLAGS'] = ldflags.uniq
end

project.save
