class dashboard (
  $bofh_email = 'test@example.com',
  $domain = 'internet.test',
  $subdomain = 'dashboard',
  $le_staging = true,
){
  class { '::docker': }
  class { '::dashboard::ingress': }

  class {'docker::compose':
    ensure  => present,
    version => '1.24.0',
  }

  file { ['/srv/dashboard/', '/srv/dashboard/compose/']:
    ensure => directory,
  }
  file {
    '/srv/dashboard/compose/docker-compose.yaml':
      source => 'puppet:///modules/dashboard/docker-compose.yaml';
    '/srv/dashboard/compose/variables.yaml':
      content => to_yaml({
        version  => '3',
        services => {
          dashboard => {
            labels => {
              'traefik.frontend.rule' => "Host: ${subdomain}.${domain}",
            },
          },
        },
      });
  }
  ~> docker_compose { 'dashboard':
    ensure        => present,
    compose_files => [
      '/srv/dashboard/compose/docker-compose.yaml',
      '/srv/dashboard/compose/variables.yaml',
    ],
  }

  file { '/usr/local/bin/dashboard':
    source => 'puppet:///modules/dashboard/dashboard.sh',
    mode   => '0755',
  }
}
