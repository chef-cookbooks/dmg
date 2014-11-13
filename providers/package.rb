# Encoding: utf-8
# Cookbook Name:: dmg
# Provider:: package
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

require 'fileutils'

include Chef::Mixin::ShellOut

use_inline_resources if defined?(use_inline_resources)

def load_current_resource
  @dmgpkg = Chef::Resource::DmgPackage.new(new_resource.name)
  @dmgpkg.app(new_resource.app)
  Chef::Log.debug("Checking for application #{new_resource.app}")
  @dmgpkg.installed(installed?)
  Chef::Log.debug("Got #{new_resource.app} installed status: #{@dmgpkg.installed}")
  @dmgpkg.version(installed_version?)
  Chef::Log.debug("Got #{new_resource.app} installed version: #{@dmgpkg.version}")
end

action :install do
  if !@dmgpkg.installed || need_to_reinstall?

    volumes_dir = new_resource.volumes_dir ? new_resource.volumes_dir : new_resource.app
    dmg_name = new_resource.dmg_name ? new_resource.dmg_name : new_resource.app
    dmg_file = "#{Chef::Config[:file_cache_path]}/#{dmg_name}.dmg"

    if new_resource.source
      remote_file "#{dmg_file} - #{@dmgpkg.name}" do
        path dmg_file
        source new_resource.source
        checksum new_resource.checksum if new_resource.checksum
      end
    end

    passphrase_cmd = new_resource.dmg_passphrase ? "-passphrase #{new_resource.dmg_passphrase}" : ''
    ruby_block "attach #{dmg_file}" do
      block do
        cmd = shell_out("hdiutil imageinfo #{passphrase_cmd} '#{dmg_file}' | grep -q 'Software License Agreement: true'")
        software_license_agreement = (cmd.exitstatus == 0)
        fail "Requires EULA Acceptance; add 'accept_eula true' to package resource" if software_license_agreement && !new_resource.accept_eula
        accept_eula_cmd = new_resource.accept_eula ? 'echo Y | PAGER=true' : ''
        shell_out!("#{accept_eula_cmd} hdiutil attach #{passphrase_cmd} '#{dmg_file}' -quiet")
      end
      not_if "hdiutil info #{passphrase_cmd} | grep -q 'image-path.*#{dmg_file}'"
    end

    case new_resource.type
    when 'app'
      fail 'Version attributes not allowed on "app"-type packages' if new_resource.version

      execute "rsync --force --recursive --links --perms --executability --owner --group --times '/Volumes/#{volumes_dir}/#{new_resource.app}.app' '#{new_resource.destination}'" do
        user new_resource.owner if new_resource.owner
      end

      file "#{new_resource.destination}/#{new_resource.app}.app/Contents/MacOS/#{new_resource.app}" do
        mode 0755
        ignore_failure true
      end
    when 'mpkg', 'pkg'
      execute "sudo installer -pkg '/Volumes/#{volumes_dir}/#{new_resource.app}.#{new_resource.type}' -target /" do
        # Prevent cfprefsd from holding up hdiutil detach for certain disk images
        environment('__CFPREFERENCES_AVOID_DAEMON' => '1') if Gem::Version.new(node['platform_version']) >= Gem::Version.new('10.8')
      end
    end

    execute "hdiutil detach '/Volumes/#{volumes_dir}' || hdiutil detach '/Volumes/#{volumes_dir}' -force"
  else
    case new_resource.type
    when 'app'
      Chef::Log.info "Already installed; to force an upgrade, remove \"#{new_resource.destination}/#{new_resource.app}.app\""
    when 'mpkg', 'pkg'
      Chef::Log.info "Already installed; to force an upgrade, try \"sudo pkgutil --forget '#{new_resource.package_id}'\""
    end
  end
end

action :remove do
  return unless @dmgpkg.installed

  case new_resource.type
  when 'app'
    dir = ::File.join(new_resource.destination, "#{new_resource.app}.app")
    Chef::Log.info "Cleaning up package #{new_resource.app} dir #{dir}"

    directory dir do
      recursive true
      action :delete
    end
  when 'mpkg', 'pkg'
    to_delete = shell_out("pkgutil --files #{new_resource.package_id}").stdout.split("\n")
    # We only care about files and dirs at the package's top level
    to_delete.delete_if { |d| d.count('/') != 0 }

    pkg_info = shell_out("pkgutil --pkg-info #{new_resource.package_id}").stdout.split("\n")
    pkg_info = pkg_info.each_with_object({}) do |line, hsh|
      hsh[line.split(':')[0].to_sym] = line.split(':')[1..-1].join(':').strip
    end

    root_dir = ::File.join(pkg_info[:volume], pkg_info[:location])

    Chef::Log.info "Cleaning up directories owned by package #{new_resource.app}"
    # Delete the items directly--hitting them one-by-one w/ Chef takes too long
    # and pollutes the INFO log with too much junk for big packages
    to_delete.map { |i| ::File.join(root_dir, i) }.each do |i|
      if ::File.directory?(i)
        Chef::Log.debug "Deleting directory #{i}"
        FileUtils.remove_dir(i)
      else
        Chef::Log.debug "Deleting file #{i}"
        ::File.delete(i)
      end
    end

    if ::Dir.entries(root_dir).delete_if { |i| %w(. ..).include?(i) }.empty?
      Chef::Log.debug "Deleting root directory #{root_dir}"
      ::Dir.delete(root_dir)
    end

    Chef::Log.info "Forgetting package #{new_resource.package_id}"
    execute "pkgutil --forget #{new_resource.package_id}"

    Chef::Log.info "Any symlinks outside #{root_dir} must be deleted manually"
  end
end

private

def installed?
  pkg_dir_exist? || pkg_in_pkgutil? ? true : false
end

def need_to_reinstall?
  if new_resource.version && @dmgpkg.version && new_resource.version != @dmgpkg.version
    Chef::Log.info "New #{new_resource.app} version #{new_resource.version} does not match installed #{@dmgpkg.version}; need to reinstall"
    true
  else
    false
  end
end

def installed_version?
  return nil unless pkg_in_pkgutil?
  shell_out("pkgutil --pkg-info #{new_resource.package_id}").stdout.each_line do |l|
    return l.split[1] if l.split[0] == 'version:'
  end
end

def pkg_dir_exist?
  ::File.directory?("#{new_resource.destination}/#{new_resource.app}.app")
end

def pkg_in_pkgutil?
  shell_out("pkgutil --pkgs='#{new_resource.package_id}'").exitstatus == 0
end
