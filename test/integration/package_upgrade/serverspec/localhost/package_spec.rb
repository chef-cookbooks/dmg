# Encoding: utf-8

require 'spec_helper'

describe package('test.changeme.pkg.dummy') do
  it 'has been upgraded' do
    expect(described_class).to be_installed.by(:pkgutil).with_version('0.2.0')
  end
end
