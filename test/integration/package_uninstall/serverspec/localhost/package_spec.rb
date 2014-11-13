# Encoding: utf-8

require 'spec_helper'

describe 'package' do
  describe command('pkgutil --pkg-info test.changeme.pkg.dummy') do
    it 'indicates the package is not installed' do
      expect(described_class).to return_exit_status(1)
    end
  end

  describe file('/opt/dummy') do
    it 'is not present on the filesystem' do
      expect(described_class).to_not be_directory
    end
  end
end
