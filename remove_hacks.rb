require 'xcodeproj'
project_path = 'ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  ldflags = config.build_settings['OTHER_LDFLAGS']
  if ldflags.is_a?(Array)
    ldflags.delete('-weak_framework')
    ldflags.delete('CoreAudioTypes')
    config.build_settings['OTHER_LDFLAGS'] = ldflags
  end
  
  fsp = config.build_settings['FRAMEWORK_SEARCH_PATHS']
  if fsp.is_a?(Array)
    fsp.delete('$(SDKROOT)/System/Library/Frameworks')
    config.build_settings['FRAMEWORK_SEARCH_PATHS'] = fsp
  end
end

project.save
