require 'xcodeproj'
project_path = 'ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  fsp = config.build_settings['FRAMEWORK_SEARCH_PATHS'] || ['$(inherited)']
  fsp = [fsp] if fsp.is_a?(String)
  fsp << '$(SDKROOT)/System/Library/Frameworks'
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] = fsp.uniq
end

project.save
