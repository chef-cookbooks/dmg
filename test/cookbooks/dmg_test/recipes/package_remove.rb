# Encoding: utf-8
#
# Cookbook Name:: dmg_test
# Recipe:: package_remove
#

package_file = 'dummy-0.1.0-1.dmg'

cookbook_file ::File.join(Chef::Config[:file_cache_path], package_file)

dmg_package 'dummy' do
  source 'file://' << ::File.join(Chef::Config[:file_cache_path], package_file)
  type 'pkg'
  package_id 'test.changeme.pkg.dummy'
  action :install
end

dmg_package 'dummy' do
  type 'pkg'
  package_id 'test.changeme.pkg.dummy'
  action :remove
end
