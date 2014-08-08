# Encoding: utf-8

require 'spec_helper'

describe 'package' do
  describe package('test.changeme.pkg.dummy') do
    it 'is installed' do
      expect(described_class).to be_installed.by(:pkgutil).with_version('0.1.0')
    end
  end

  describe file('/opt/dummy') do
    it 'is a directory on the filesystem' do
      expect(described_class).to be_directory
    end
  end
end
