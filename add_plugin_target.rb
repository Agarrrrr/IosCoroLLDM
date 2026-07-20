require 'xcodeproj'
project_path = 'ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

swift_file = project.main_group.find_subpath('App', true).new_file('NativePDFPlugin.swift')
m_file = project.main_group.find_subpath('App', true).new_file('NativePDFPlugin.m')

target.add_file_references([swift_file, m_file])

project.save
