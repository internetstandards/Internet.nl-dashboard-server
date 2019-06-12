# dashboard app, queue and database
class dashboard::app (
  $image_tag = latest,
  $hosts = [],
) {
  file { '/usr/local/bin/dashboard':
    source => 'puppet:///modules/dashboard/dashboard.sh',
    mode   => '0755',
  }
  -> ::Docker::Run['dashboard']

  file { '/usr/local/bin/dashboard-update':
    content => epp('dashboard/dashboard-update.sh', {
      image_tag=>$image_tag
    }),
    mode   => '0755',
  }

  $_hosts = join($hosts << "${dashboard::subdomain}.${dashboard::domain}", ',')

  ::docker::run { 'dashboard':
    image                 => "internetstandards/dashboard:${image_tag}",
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    labels                => [
      'traefik.enable=true',
      'traefik.frontend.priority=10',
      "traefik.frontend.rule=Host:${_hosts}",
    ],
    env                   => [
      'SECRET_KEY=saldkfjklsdajfklsdajflksadjflkj',
      'FIELD_ENCRYPTION_KEY=rYFZXHmpDNzyLKkHT-mfK_VR2vbOmrLkZaBwsNV8CQA=',
      'ALLOWED_HOSTS=*',
      'DJANGO_DATABASE=production',
      'DB_ENGINE=postgresql_psycopg2',
      'DB_HOST=db',
      'BROKER=redis',
    ],
  }
  ~> exec { 'migrate-db':
    command     => '/usr/local/bin/dashboard migrate',
    refreshonly => true,
    # might fail if started to early after container start
    tries       => 5,
    try_sleep   => 5,
  }

  ::docker::run { 'worker':
    image                 => "internetstandards/dashboard:${image_tag}",
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    env                   => [
      'SECRET_KEY=saldkfjklsdajfklsdajflksadjflkj',
      'FIELD_ENCRYPTION_KEY=YFZXHmpDNzyLKkHT-mfK_VR2vbOmrLkZaBwsNV8CQA=',
      'ALLOWED_HOSTS=*',
      'DJANGO_DATABASE=production',
      'DB_ENGINE=postgresql_psycopg2',
      'DB_HOST=db',
      'BROKER=redis://broker:6379/0',
      'C_FORCE_ROOT=1',
    ],
    command => 'celery_dashboard worker -Q storage -l debug',
  }

  ::docker::run { 'db':
    image                 => 'postgres:11',
    systemd_restart       => always,
    volumes               => [
      '/srv/dashboard/db/:/var/lib/postgresql/data',
    ],
    ports                 => [],
    net                   => dashboard,
    health_check_interval => 60,
    env                   => [
      'POSTGRES_DB=dashboard',
      'POSTGRES_USER=dashboard',
      'POSTGRES_PASSWORD=dashboard',
    ],
    links                 => [
      'db:db',
      'broker:broker',
    ],
  }

  ::docker::run { 'broker':
    image                 => 'redis',
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
  }
}
