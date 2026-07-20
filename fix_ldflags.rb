require 'xcodeproj'
project_path = 'ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  ldflags = config.build_settings['OTHER_LDFLAGS'] || ['$(inherited)']
  ldflags = [ldflags] if ldflags.is_a?(String)
  
  # Remove incorrect entries
  ldflags.delete('MarketplaceKit')
  ldflags.delete('CoreAudioTypes')
  ldflags.delete('-weak_framework')
  
  # Re-add them correctly without uniq!
  ldflags << "-weak_framework" << "MarketplaceKit"
  ldflags << "-weak_framework" << "CoreAudioTypes"
  
  config.build_settings['OTHER_LDFLAGS'] = ldflags
end

project.save
