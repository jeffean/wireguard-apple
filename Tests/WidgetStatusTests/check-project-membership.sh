#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
PROJECT_FILE="$REPOSITORY_ROOT/WireGuard.xcodeproj/project.pbxproj"

plutil -convert json -o - "$PROJECT_FILE" | ruby -rjson -e '
objects = JSON.parse(STDIN.read).fetch("objects")
required_sources = [
  "NETunnelProviderProtocol+Extension.swift",
  "TunnelConfigurationMigration.swift",
]
target_names = [
  "WireGuardiOS",
  "WireGuardNetworkExtensioniOS",
  "WireGuardmacOS",
  "WireGuardNetworkExtensionmacOS",
]

target_names.each do |target_name|
  target = objects.values.find do |object|
    object["isa"] == "PBXNativeTarget" && object["name"] == target_name
  end
  abort("Missing target: #{target_name}") unless target

  source_paths = target.fetch("buildPhases").flat_map do |phase_id|
    phase = objects.fetch(phase_id)
    next [] unless phase["isa"] == "PBXSourcesBuildPhase"

    phase.fetch("files", []).filter_map do |build_file_id|
      build_file = objects.fetch(build_file_id)
      file_reference = objects.fetch(build_file.fetch("fileRef"))
      file_reference["path"]
    end
  end

  missing_sources = required_sources - source_paths
  abort("#{target_name} is missing sources: #{missing_sources.join(", ")}") unless missing_sources.empty?
end

puts "PASS: Xcode shared model target membership"
'
