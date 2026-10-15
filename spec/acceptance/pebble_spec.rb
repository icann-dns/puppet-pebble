# frozen_string_literal: true

require 'spec_helper_acceptance'
require 'json'

describe 'pebble' do
  it 'installs and configures Pebble idempotently' do
    manifest = <<~PUPPET
      class { 'pebble': }
    PUPPET

    apply_manifest(manifest, catch_failures: true)
    apply_manifest(manifest, catch_changes: true)
  end

  it 'configures external account binding credentials' do
    manifest = <<~PUPPET
      class { 'pebble':
        eab => { 'acceptance-kid' => 'acceptance-hmac-key' },
      }
    PUPPET

    apply_manifest(manifest, catch_failures: true)
    config = JSON.parse(file('/etc/pebble/pebble-config.json').content).fetch('pebble')

    expect(config).to include(
      'externalAccountBindingRequired' => true,
      'externalAccountMACKeys'         => { 'acceptance-kid' => 'acceptance-hmac-key' },
    )
  end

  describe package('pebble') do
    it { is_expected.to be_installed }
  end

  describe service('pebble') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe file('/etc/pebble/pebble-config.json') do
    it { is_expected.to be_file }
    it { is_expected.to be_owned_by 'root' }
    it { is_expected.to contain '"listenAddress":"0.0.0.0:14000"' }
    it { is_expected.to contain '"managementListenAddress":"0.0.0.0:15000"' }
  end
end
