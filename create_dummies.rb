require 'fileutils'
require 'xcodeproj'

dir = "ios/DummySDK"
FileUtils.mkdir_p("#{dir}/usr/lib/swift")
FileUtils.mkdir_p("#{dir}/System/Library/Frameworks/MarketplaceKit.framework")
FileUtils.mkdir_p("#{dir}/System/Library/Frameworks/CoreAudioTypes.framework")

tbd_template = <<~TBD
--- !tapi-tbd-v3
archs:           [ arm64, x86_64 ]
platform:        ios
flags:           [ flat_namespace ]
install-name:    '__INSTALL_NAME__'
current-version: 1
compatibility-version: 1
objc-constraint: none
exports:
  - archs:           [ arm64, x86_64 ]
    symbols:         [ __SYMBOLS__ ]
...
TBD

libs = [
  "swiftXPC", "swift_Builtin_float", "swift_errno", "swift_math", 
  "swift_signal", "swift_stdio", "swift_time", "swiftsys_time", "swiftunistd"
]

libs.each do |lib|
  content = tbd_template.gsub('__INSTALL_NAME__', "/usr/lib/swift/lib#{lib}.dylib")
  # Add the force load symbol that the linker is complaining about!
  content = content.gsub('__SYMBOLS__', "'__swift_FORCE_LOAD_$_#{lib}'")
  File.write("#{dir}/usr/lib/swift/lib#{lib}.tbd", content)
end

# MarketplaceKit
mk_content = tbd_template.gsub('__INSTALL_NAME__', '/System/Library/Frameworks/MarketplaceKit.framework/MarketplaceKit')
mk_content = mk_content.gsub('__SYMBOLS__', "'_$s14MarketplaceKit14AppDistributorO10testFlightyA2CmFWC', '_$s14MarketplaceKit14AppDistributorO11marketplaceyACSScACmFWC', '_$s14MarketplaceKit14AppDistributorO3webyA2CmFWC', '_$s14MarketplaceKit14AppDistributorO5otheryA2CmFWC', '_$s14MarketplaceKit14AppDistributorO7currentACvgZ', '_$s14MarketplaceKit14AppDistributorO7currentACvgZTu', '_$s14MarketplaceKit14AppDistributorO8appStoreyA2CmFWC', '_$s14MarketplaceKit14AppDistributorOMa', '_$s14MarketplaceKit14AppDistributorOMn'")
File.write("#{dir}/System/Library/Frameworks/MarketplaceKit.framework/MarketplaceKit.tbd", mk_content)

# CoreAudioTypes
ca_content = tbd_template.gsub('__INSTALL_NAME__', '/System/Library/Frameworks/CoreAudioTypes.framework/CoreAudioTypes')
ca_content = ca_content.gsub('__SYMBOLS__', '')
File.write("#{dir}/System/Library/Frameworks/CoreAudioTypes.framework/CoreAudioTypes.tbd", ca_content)

# Now update the Xcode project to use this DummySDK
project_path = 'ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  lsp = config.build_settings['LIBRARY_SEARCH_PATHS'] || ['$(inherited)']
  lsp = [lsp] if lsp.is_a?(String)
  lsp << '"$(SRCROOT)/DummySDK/usr/lib/swift"'
  config.build_settings['LIBRARY_SEARCH_PATHS'] = lsp.uniq
  
  fsp = config.build_settings['FRAMEWORK_SEARCH_PATHS'] || ['$(inherited)']
  fsp = [fsp] if fsp.is_a?(String)
  fsp << '"$(SRCROOT)/DummySDK/System/Library/Frameworks"'
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] = fsp.uniq

  ldflags = config.build_settings['OTHER_LDFLAGS'] || ['$(inherited)']
  ldflags = [ldflags] if ldflags.is_a?(String)
  libs.each { |lib| ldflags << "-weak-l#{lib}" }
  ldflags << "-weak_framework" << "MarketplaceKit"
  ldflags << "-weak_framework" << "CoreAudioTypes"
  
  # ALSO add `-Wl,-undefined,dynamic_lookup` to suppress the remaining Swift 5.10 symbols like `_swift_stdlib_isStackAllocationSafe`!
  ldflags << "-Wl,-undefined,dynamic_lookup"
  
  config.build_settings['OTHER_LDFLAGS'] = ldflags.uniq
end

project.save
