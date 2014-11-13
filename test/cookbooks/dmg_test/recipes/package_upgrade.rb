# Encoding: utf-8
#
# Cookbook Name:: dmg_test
# Recipe:: package_upgrade
#

package_files = %w(dummy-0.1.0-1.dmg dummy-0.2.0-1.dmg)

package_files.each_with_index do |f, i|
  cookbook_file ::File.join(Chef::Config[:file_cache_path], f)

  dmg_package "dummy#{i}" do
    app 'dummy'
    version f.sub(/^dummy-/, '').sub(/-[0-9]\.dmg$/, '')
    source 'file://' << ::File.join(Chef::Config[:file_cache_path], f)
    type 'pkg'
    package_id 'test.changeme.pkg.dummy'
  end
end
