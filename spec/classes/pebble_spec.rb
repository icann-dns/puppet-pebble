# frozen_string_literal: true

require 'spec_helper'

describe 'pebble' do
  let(:facts) { { path: '/usr/bin:/bin:/usr/sbin:/sbin' } }

  it { is_expected.to compile }

  it { is_expected.to contain_package('pebble').with_ensure('installed') }

  it { is_expected.to contain_group('pebble').with_ensure('present') }

  it do
    is_expected.to contain_user('pebble').with(
      'ensure' => 'present',
      'gid'    => 'pebble',
      'shell'  => '/usr/sbin/nologin',
      'home'   => '/etc/pebble',
    )
  end

  it do
    is_expected.to contain_file('/etc/pebble/pebble-config.json').with(
      'ensure' => 'file',
      'owner'  => 'root',
      'group'  => 'pebble',
      'mode'   => '0640',
    ).with_content(%r{"listenAddress"\s*:\s*"0\.0\.0\.0:14000"})
                                                                 .with_content(%r{"managementListenAddress"\s*:\s*"0\.0\.0\.0:15000"})
                                                                 .with_content(%r{"httpPort"\s*:\s*5002})
                                                                 .with_content(%r{"tlsPort"\s*:\s*5001})
  end

  it do
    is_expected.to contain_systemd__manage_unit('pebble.service').with(
      'ensure'          => 'present',
      'service_restart' => true,
      'unit_entry'      => {
        'Description' => 'Pebble ACME test server',
        'After'       => 'network.target',
      },
    )
  end

  context 'with custom package and service options' do
    let(:params) do
      {
        package_name: 'pebble-server',
        strict: true,
        dns_resolver: '10.0.0.1:53',
      }
    end

    it { is_expected.to contain_package('pebble-server').with_ensure('installed') }

    it do
      service_entry = catalogue.resource('Systemd::Manage_unit', 'pebble.service')[:service_entry]

      expect(service_entry).to include(
        'ExecStart' => a_string_matching(%r{/usr/bin/pebble}),
        'User'      => 'pebble',
        'Group'     => 'pebble',
      )
    end
  end
end
