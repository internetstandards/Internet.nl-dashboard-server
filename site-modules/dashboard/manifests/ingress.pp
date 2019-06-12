# manage ingress webserver, caching, general maintenance
class dashboard::ingress inherits dashboard {
  file { '/etc/traefik/':
    ensure => directory,
  }
  file { '/etc/traefik/traefik.toml':
    content => epp('dashboard/traefik.toml', {
      bofh_email => $bofh_email,
      domain     => $domain,
      subdomain  => $subdomain,
      le_staging => $le_staging,
    }),
  }

  file { ['/var/www/', '/var/www/maintenance']:
    ensure => directory,
  }
  file { '/var/www/maintenance/index.html':
    content => epp('dashboard/maintenance.html'),
  }

  ufw::allow { 'allow-http': port => 80, }
  ufw::allow { 'allow-https': port => 443, }

  if $env == lab {
    ufw::allow { 'allow-traefik-dash': port => 8000, }
  }

  File['/etc/traefik/traefik.toml']
  ~> ::docker::run { 'traefik':
    image                 => 'traefik:latest',
    systemd_restart       => always,
    volumes               => [
      '/etc/traefik/:/etc/traefik/',
      '/var/run/docker.sock:/var/run/docker.sock:ro',
    ],
    ports                 => [
      '80:80',
      '443:443',
      '8000:8000',
    ],
    net                   => dashboard,
    health_check_interval => 60,
  }

  ::docker::run { 'maintenance':
    image                 => 'python:3',
    command               => 'python -m http.server 80',
    extra_parameters      => [
      '--workdir=/var/www/maintenance',
    ],
    systemd_restart       => always,
    volumes               => [
      '/var/www/maintenance/:/var/www/maintenance/',
    ],
    labels                => [
      'traefik.enable=true',
      'traefik.frontend.priority=1',
      'traefik.frontend.rule=Path:/',
      'traefik.port=80',
    ],
    net                   => dashboard,
    health_check_interval => 60,
  }
}
