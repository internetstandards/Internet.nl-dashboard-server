# configure dashboard application stack
class dashboard (
  $bofh_email = 'test@example.com',
  $domain = 'internet.test',
  $subdomain = 'dashboard',
  $le_staging = true,
  $ipv6_subnet = undef,
){
  $docker_subnet = '172.17.0.0/16'
  $dashboard_subnet = '172.18.0.0/16'

  if $ipv6_subnet {
    $ipv6_parameters = ['--ipv6', "--fixed-cidr-v6=${ipv6_subnet}"]
  } else {
    $ipv6_parameters = []
  }

  class {'::docker':
    iptables         => false,
    fixed_cidr       => $docker_subnet,
    extra_parameters => $ipv6_parameters,
  }

  docker_network { 'dashboard':
    ensure => present,
    subnet => $dashboard_subnet,
  } -> Docker::Run <| |>

  firewall { '100 snat for docker containers':
    chain    => 'POSTROUTING',
    jump     => 'MASQUERADE',
    proto    => all,
    outiface => '! docker0',
    source   => '172.17.0.0/14',
    table    => nat,
  }

  firewall { '100 forwarding between docker containers':
    chain       => 'FORWARD',
    source      => '172.17.0.0/14',
    destination => '172.17.0.0/14',
    action      => accept,
  }

  firewall { '100 forwarding containers to internet':
    chain    => 'FORWARD',
    proto    => all,
    outiface => 'docker0',
    action   => accept,
  }

  # external facing webserver
  class { '::dashboard::ingress': }

  # application, queue, database
  class { '::dashboard::app': }
}
