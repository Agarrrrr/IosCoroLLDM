require 'xcodeproj'
project_path = 'ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  lsp = config.build_settings['LIBRARY_SEARCH_PATHS'] || ['$(inherited)']
  lsp = [lsp] if lsp.is_a?(String)
  lsp << '$(TOOLCHAIN_DIR)/usr/lib/swift/$(PLATFORM_NAME)'
  lsp << '$(TOOLCHAIN_DIR)/usr/lib/swift-5.0/$(PLATFORM_NAME)'
  lsp << '$(SDKROOT)/usr/lib/swift'
  config.build_settings['LIBRARY_SEARCH_PATHS'] = lsp.uniq
end

project.save
