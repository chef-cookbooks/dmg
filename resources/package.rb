#
# Cookbook Name:: dmg
# Resource:: package
#
# Copyright 2011, Joshua Timberman
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/shell_out'

actions :install

attribute :app, :kind_of => String, :name_attribute => true
attribute :package_id, :kind_of => [ Array, String ], :default => nil
attribute :source, :kind_of => String, :default => nil
attribute :destination, :kind_of => String, :default => "/Applications"
attribute :checksum, :kind_of => String, :default => nil
attribute :volumes_dir, :kind_of => String, :default => nil
attribute :dmg_name, :kind_of => String, :default => nil
attribute :type, :kind_of => String, :default => "app", :regex => /pkg|mpkg|app/
attribute :installed_resource, :kind_of => String, :default => nil

def initialize(name, run_context=nil)
  super
  @action = :install
end

def installed?
  if installed_resource
    Chef::Log.debug("[DMG] Checking for installed resource: #{installed_resource}")

    return ::File.exist?(installed_resource)
  end

  case type
  when "pkg", "mpkg"
    Chef::Log.debug("[DMG] Checking for installed #{type}: #{package_id}")
    
    return false if package_id.nil? || package_id.empty?

    result = Chef::ShellOut.new("pkgutil --pkgs", :env => nil).run_command
    pkg_ids = result.stdout.split("\n")

    return false if pkg_ids.empty?

    case package_id
    when String
      pkg_ids.include?(package_id)
    when Array
      (pkg_ids & package_id) == package_id
    end
  when "app"
    Chef::Log.debug("[DMG] Checking for installed application: #{app}")
    ::File.directory?("#{destination}/#{app}.app")
  end
end
