#!/usr/bin/env ruby
# Standalone release package builder for Extension Sources

require 'fileutils'
require 'pathname'
require 'zip'
require 'json'

# Read extension info from extension.json
def read_extension_info(source_path)
  pattern = File.join(source_path, '*.rb')
  root_rb = Dir.glob(pattern).to_a.first
  basename = File.basename(root_rb, '.*')
  support_folder = File.join(source_path, basename)
  json_file = File.join(support_folder, 'extension.json')
  extension_json = File.read(json_file, encoding: 'utf-8')
  JSON.parse(extension_json, symbolize_names: true)
end

### Configure Paths ############################################################

project_path = File.expand_path('..', __dir__)
project_pathname = Pathname.new(project_path)

source_path = File.join(project_path, "src")
source_pathname = Pathname.new(source_path)

archive_path = File.join(project_path, "archive")
FileUtils.mkdir_p(archive_path)

### Configure Files ############################################################

extension = read_extension_info(source_path)

extension_name = extension[:name]
puts "Extension Name: #{extension_name}"

extension_id = extension[:product_id]
version = extension[:version]
puts "Version: #{version}"

build_version = version
build_date = Time.now.strftime("%Y-%m-%d")

pattern = File.join(source_path, '*.rb')
root_rb = Dir.glob(pattern).to_a.first
basename = File.basename(root_rb, '.rb')

archive_name = "#{basename}_#{build_version}_#{build_date}"
archive = File.join(archive_path, "#{archive_name}.rbz")

### Package ####################################################################

puts "Creating RBZ archive..."
puts "Source: #{source_path}"
puts "Destination: #{archive}"

if File.exist?(archive)
  puts "Archive already exists. Deleting existing archive."
  File.delete(archive)
end

build_files_pattern = File.join(source_path, "**", "**")
Zip::File.open(archive, create: true) do |zipfile|
  build_files = Dir.glob(build_files_pattern)
  build_files.each do |file_item|
    next if File.directory?(file_item)
    pathname = Pathname.new(file_item)
    relative_name = pathname.relative_path_from(source_pathname)
    puts "  Archiving: #{relative_name}"
    zipfile.add(relative_name, file_item)
  end
end

puts ""
puts "Packing done!"
puts "Archive: #{archive}"
