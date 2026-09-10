#!/usr/bin/env ruby
# Generise Xcode build konfiguracije i scheme po tenantu iz tenants/*/tenant.yaml.
#
#   tool/gen_ios_flavors.sh
#
# Zasto Ruby: project.pbxproj se ne smije editovati tekstualno. Neispravan
# pbxproj ruši projekat za sve flavore odjednom, a greška se ne vidi dok se ne
# otvori Xcode. `xcodeproj` gem dolazi sa CocoaPodsom, koji je za Flutter iOS
# ionako obavezan, pa ne uvodi novu zavisnost.
#
# Sta Flutter tacno traži (packages/flutter_tools/lib/src/ios/xcodeproj.dart):
#   scheme  = sentenceCase(flavor), uz case-insensitive poklapanje
#   config  = "<Debug|Profile|Release>-<scheme>"
# Zato se scheme zove tacno kao flavor, a konfiguracije nose njegovo ime.
require 'xcodeproj'
require 'yaml'
require 'fileutils'

root = File.expand_path('..', __dir__)
project_path = File.join(root, 'apps/client/ios/Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

flavors = Dir.glob(File.join(root, 'tenants/*/tenant.yaml')).sort.map do |file|
  dir = File.basename(File.dirname(file))
  next if dir.start_with?('_')

  config = YAML.load_file(file)
  next unless config.dig('targets', 'ios')

  config.dig('tenant', 'flavor')
end.compact

abort 'Nijedan iOS tenant nije pronađen u tenants/.' if flavors.empty?

MODES = %w[Debug Profile Release].freeze
# buildSettings nadjacava xcconfig, pa se ovi kljucevi moraju skloniti iz
# flavor konfiguracija — inace bi bundleId i ime ostali oni iz templatea.
OVERRIDDEN = %w[
  PRODUCT_BUNDLE_IDENTIFIER
  PRODUCT_NAME
  ASSETCATALOG_COMPILER_APPICON_NAME
  INFOPLIST_KEY_CFBundleDisplayName
].freeze

flavors_group = project.main_group['Flutter'] || project.main_group
runner = project.targets.find { |t| t.name == 'Runner' }
others = project.targets.reject { |t| t.name == 'Runner' }

def xcconfig_ref(project, group, relative_path)
  group.files.find { |f| f.path == relative_path } ||
    group.new_reference(relative_path).tap { |r| r.source_tree = 'SOURCE_ROOT' }
end

flavors.each do |flavor|
  MODES.each do |mode|
    name = "#{mode}-#{flavor}"

    # Projekat: kopija osnovne konfiguracije pod novim imenom.
    [project.build_configuration_list, *others.map(&:build_configuration_list)].each do |list|
      next if list[name]

      base = list[mode] or next
      copy = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
      copy.name = name
      copy.build_settings = base.build_settings.dup
      copy.base_configuration_reference = base.base_configuration_reference
      list.build_configurations << copy
    end

    # Runner: kopija + wrapper xcconfig + brisanje nadjacavajucih kljuceva.
    list = runner.build_configuration_list
    unless list[name]
      base = list[mode]
      copy = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
      copy.name = name
      copy.build_settings = base.build_settings.dup
      OVERRIDDEN.each { |key| copy.build_settings.delete(key) }
      copy.base_configuration_reference =
        xcconfig_ref(project, flavors_group, "flavors/#{name}.xcconfig")
      list.build_configurations << copy
    end
  end

  # Scheme se zove tacno kao flavor; Flutter ga tako i traži.
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(runner)
  scheme.set_launch_target(runner)
  scheme.build_action.parallelize_buildables = true
  scheme.launch_action.build_configuration = "Debug-#{flavor}"
  scheme.test_action.build_configuration = "Debug-#{flavor}"
  scheme.analyze_action.build_configuration = "Debug-#{flavor}"
  scheme.profile_action.build_configuration = "Profile-#{flavor}"
  scheme.archive_action.build_configuration = "Release-#{flavor}"
  scheme.save_as(project_path, flavor, true)
  puts "#{flavor}: konfiguracije #{MODES.map { |m| "#{m}-#{flavor}" }.join(', ')} + scheme"
end

project.save
puts "Sacuvano: #{project_path}"
