# @summary Install and configure Let's Encrypt Pebble on Ubuntu
#
# @param package_name Apt package providing Pebble
# @param user User running pebble
# @param group Group running pebble
# @param config_dir Directory for configuration files
# @param listen_address ACME API listen address
# @param management_listen_address Management API listen address
# @param http_port Port used for HTTP-01 validation
# @param tls_port Port used for TLS-ALPN-01 validation
# @param strict Whether to run pebble with -strict
# @param dns_resolver Optional DNS resolver (host:port)
# @param va_always_valid Whether to enable the VA always valid mode
# @param va_nosleep Whether to enable the VA no sleep mode
# @param va_sleeptime Sleep time for the VA in seconds
# @param wfe_noncereject Value for the PEBBLE_WFE_NONCEREJECT environment variable
# @param authzreuse Value for the PEBBLE_AUTHZREUSE environment variable
# @param wfe_orders_per_page Value for the PEBBLE_WFE_ORDERS_PER_PAGE environment variable
# @param alternate_roots Value for the PEBBLE_ALTERNATE_ROOTS environment variable
# @param chain_length Value for the PEBBLE_CHAIN_LENGTH environment variable
# @param certificate_source Path to the certificate file
# @param private_key_source Path to the private key file
#
class pebble (
  String             $package_name              = 'pebble',
  String             $user                      = 'pebble',
  String             $group                     = 'pebble',
  Stdlib::Unixpath   $config_dir                = '/etc/pebble',
  String             $listen_address            = '0.0.0.0:14000',
  String             $management_listen_address = '0.0.0.0:15000',
  Stdlib::Port       $http_port                 = 5002,
  Stdlib::Port       $tls_port                  = 5001,
  Boolean            $strict                    = false,
  Boolean            $va_nosleep                = false,
  Boolean            $va_always_valid           = false,
  Integer[1]         $va_sleeptime              = 15,
  Integer[0, 100]    $wfe_noncereject           = 5,
  Integer[0, 100]    $wfe_orders_per_page       = 3,
  Integer[0, 100]    $authzreuse                = 50,
  Boolean            $alternate_roots           = false,
  Integer[1]         $chain_length              = 1,
  Stdlib::Filesource $certificate_source        = 'puppet:///modules/pebble/pebble.minica.pem',
  Stdlib::Filesource $private_key_source        = 'puppet:///modules/pebble/pebble.minica.key.pem',
  Optional[String]   $dns_resolver              = undef,
) {
  $binary = '/usr/bin/pebble'

  stdlib::ensure_packages($package_name)

  group { $group:
    ensure => present,
    system => true,
  }

  user { $user:
    ensure => present,
    system => true,
    gid    => $group,
    shell  => '/usr/sbin/nologin',
    home   => $config_dir,
  }

  $config = {
    'pebble' => {
      'listenAddress'           => $listen_address,
      'managementListenAddress' => $management_listen_address,
      'certificate'             => "${config_dir}/cert.pem",
      'privateKey'              => "${config_dir}/key.pem",
      'httpPort'                => $http_port,
      'tlsPort'                 => $tls_port,
    },
  }
  $environment = {
    'PEBBLE_VA_ALWAYS_VALID'     => $va_always_valid.bool2str('1', '0'),
    'PEBBLE_VA_NOSLEEP'          => $va_nosleep.bool2str('1', '0'),
    'PEBBLE_VA_SLEEPTIME'        => $va_sleeptime,
    'PEBBLE_WFE_NONCEREJECT'     => $wfe_noncereject,
    'PEBBLE_AUTHZREUSE'          => $authzreuse,
    'PEBBLE_WFE_ORDERS_PER_PAGE' => $wfe_orders_per_page,
    'PEBBLE_ALTERNATE_ROOTS'     => $alternate_roots.bool2str('1', '0'),
    'PEBBLE_CHAIN_LENGTH'        => $chain_length,
  }.map |$k, $v| { "${k}=${v}" }

  file {
    default:
      ensure => file,
      owner  => 'root',
      group  => $group,
      mode   => '0640',
      notify => Service['pebble'];
    $config_dir:
      ensure => directory,
      mode   => '0755';
    "${config_dir}/pebble-config.json":
      content => $config.stdlib::to_json();
    "${config_dir}/cert.pem":
      source => $certificate_source;
    "${config_dir}/key.pem":
      source => $private_key_source;
  }

  $args = {
    'config'    => "${config_dir}/pebble-config.json",
    'strict'    => $strict,
    'dnsserver' => $dns_resolver,
  }.filter |$k, $v| { $v =~ NotUndef }
  $cmd = extlib::argparse($args, $binary, ' ', ',', '-')

  systemd::manage_unit { 'pebble.service':
    ensure          => present,
    service_restart => true,
    unit_entry      => {
      'Description' => 'Pebble ACME test server',
      'After'       => 'network.target',
    },
    service_entry   => {
      'Type'                    => 'simple',
      'ExecStart'               => $cmd,
      'Restart'                 => 'on-failure',
      'User'                    => $user,
      'Group'                   => $group,
      'Environment'             => $environment,
      'ProtectSystem'           => 'strict',
      'PrivateTmp'              => true,
      'ProtectHome'             => 'read-only',
      'ProtectClock'            => true,
      'ProtectKernelLogs'       => true,
      'ProtectKernelModules'    => true,
      # TODO: not recognised by puppet module
      # 'RestrictSUIDGUID'        => true,
      'RestrictAddressFamilies' => ['AF_INET', 'AF_INET6'],
      'UMask'                   => '0077',
      'RestrictRealtime'        => true,
      'MemoryDenyWriteExecute'  => true,
    },
  }
  service { 'pebble':
    ensure  => running,
    enable  => true,
    require => Systemd::Manage_unit['pebble.service'],
  }
}
