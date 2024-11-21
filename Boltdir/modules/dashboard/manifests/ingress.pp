# manage ingress webserver, caching, general maintenance
class dashboard::ingress {
  file { '/etc/traefik/':
    ensure => directory,
  }
  file { '/etc/traefik/traefik.yaml':
    content => epp('dashboard/traefik.yaml', {
      bofh_email => $dashboard::bofh_email,
      domain     => $dashboard::domain,
      subdomain  => $dashboard::subdomain,
      hosts      => $dashboard::hosts,
      le_staging => $dashboard::le_staging,
    }),
  }

  file { '/etc/traefik/file-provider.yaml':
    content => epp('dashboard/file-provider.yaml', {}),
  }

  file { ['/var/www/', '/var/www/maintenance']:
    ensure => directory,
  }
  file { '/var/www/maintenance/index.html':
    content => epp('dashboard/maintenance.html'),
  }

  base::firewall::allow { ['80', '443']: }

  if $::env == lab {
    base::firewall::allow { '8000': }
  }

  $ports = $::env ? {
    lab => [
      '80:80',
      '443:443',
      '8000:8000',
    ],
    default => [
      '80:80',
      '443:443',
    ]
  }

  File['/etc/traefik/traefik.yaml', '/etc/traefik/file-provider.yaml']
  ~> ::docker::run { 'traefik':
    # Traefik 2.x configuration is not backwards compatible, sticking to 1.7 for now.
    image                 => 'traefik:2.11',
    systemd_restart       => always,
    volumes               => [
      '/etc/traefik/:/etc/traefik/',
      '/var/run/docker.sock:/var/run/docker.sock:ro',
    ],
    ports                 => $ports,
    # net                   => dashboard,
    health_check_interval => 60,
    net                   => host,
  }

  ::docker::run { 'maintenance':
    image                 => 'python:3',
    command               => 'python -m http.server 80',
    extra_parameters      => [
      '--workdir=/var/www/maintenance',
      '--expose=80',
    ],
    systemd_restart       => always,
    volumes               => [
      '/var/www/maintenance/:/var/www/maintenance/',
    ],
    labels                => [
      'traefik.enable=true',
      "traefik.http.routers.maintenance.rule=PathPrefix(\"/\")",
      'traefik.http.routers.maintenance.priority=1',
      'traefik.http.routers.maintenance.entrypoints=websecure',
    ],
    health_check_interval => 60,
  }
}
