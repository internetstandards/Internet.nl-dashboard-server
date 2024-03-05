# dashboard app, queue and database
class dashboard::app (
  $secret_key,
  $field_encryption_key,
  $image_tag = latest,
  $sentry_dsn = undef,
  $auto_update_interval = undef,
) {
  file { '/usr/local/bin/dashboard':
    source => 'puppet:///modules/dashboard/dashboard.sh',
    mode   => '0755',
  }
  -> ::Docker::Run['dashboard']

  $_hosts = $dashboard::hosts << "${dashboard::subdomain}.${dashboard::domain}"

  $hosts = join(suffix(prefix($_hosts, '"'), '"'),", ")

  ::docker::run { 'dashboard-static':
    image                 => "internetstandards/dashboard-static:${image_tag}",
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    labels                => [
      'traefik.enable=true',
      "traefik.http.routers.dashboard-static.rule='Host(${hosts})'",
      'traefik.http.routers.dashboard-static.priority=10',
      'traefik.http.routers.dashboard-static.entrypoints=websecure',
    ],
  }

  # all paths that should be routed to Django dynamic backend
  $dynamic_content_paths = join(suffix(prefix([
    '/accounts/',
    '/account/',
    '/admin/',
    '/data/',
    '/jet/',
    '/logout',
    '/mail/',
    '/session/',
    '/static/',
    '/upload/',
    '/security.txt',
    '/.well-known/security.txt'
  ], '"'), '"'), ', ')

  ::docker::run { 'dashboard':
    image                 => "internetstandards/dashboard:${image_tag}",
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    labels                => [
      'traefik.enable=true',
      # all dynamic content should be served by Django, otherwise fallback to static content
      "traefik.http.routers.dashboard.rule='Host(${hosts}) && PathPrefix(${dynamic_content_paths})'",
      'traefik.http.routers.dashboard.priority=20',
      'traefik.http.routers.dashboard.entrypoints=websecure',
    ],
    env                   => [
      "SECRET_KEY=${secret_key}",
      "FIELD_ENCRYPTION_KEY=${field_encryption_key}",
      'ALLOWED_HOSTS=*',
      'UWSGI_HARAKIRI=3600',
      'DJANGO_DATABASE=production',
      'DB_ENGINE=postgresql_psycopg2',
      'DB_HOST=db',
      'WORKER_ROLE=default',
      'BROKER=redis://broker:6379/0',
      "SENTRY_DSN=${sentry_dsn}",
    ],
  }
  ~> exec { 'migrate-db':
    command     => '/bin/systemctl start dashboard-migrate',
    refreshonly => true,
    # might fail if started to early after container start due to container having to be downloaded and started
    tries       => 60,
    try_sleep   => 5,
    timeout     => 600,
  }

  [
    ::Docker::Run[broker],
    ::Docker::Run[db],
  ] -> Exec['migrate-db']

  ::docker::run { 'dashboard-worker':
    image                 => "internetstandards/dashboard:${image_tag}",
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    env                   => [
      "SECRET_KEY=${secret_key}",
      "FIELD_ENCRYPTION_KEY=${field_encryption_key}",
      'ALLOWED_HOSTS=*',
      'DJANGO_DATABASE=production',
      'DB_ENGINE=postgresql_psycopg2',
      'DB_HOST=db',
      'WORKER_ROLE=default_ipv4',
      'BROKER=redis://broker:6379/0',
      'C_FORCE_ROOT=1',
      "SENTRY_DSN=${sentry_dsn}",
    ],
    command               => 'celery_dashboard worker -Q storage,celery,isolated',
  }

  ::docker::run { 'dashboard-worker-reporting':
    image                 => "internetstandards/dashboard:${image_tag}",
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    env                   => [
      "SECRET_KEY=${secret_key}",
      "FIELD_ENCRYPTION_KEY=${field_encryption_key}",
      'ALLOWED_HOSTS=*',
      'DJANGO_DATABASE=production',
      'DB_ENGINE=postgresql_psycopg2',
      'DB_HOST=db',
      'WORKER_ROLE=reporting',
      'BROKER=redis://broker:6379/0',
      'C_FORCE_ROOT=1',
      "SENTRY_DSN=${sentry_dsn}",
    ],
    command               => 'celery_dashboard worker -Q reporting',
  }

  ::docker::run { 'dashboard-worker-scanning':
    image                 => "internetstandards/dashboard:${image_tag}",
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    env                   => [
      "SECRET_KEY=${secret_key}",
      "FIELD_ENCRYPTION_KEY=${field_encryption_key}",
      'ALLOWED_HOSTS=*',
      'DJANGO_DATABASE=production',
      'DB_ENGINE=postgresql_psycopg2',
      'DB_HOST=db',
      'WORKER_ROLE=default_ipv4',
      'BROKER=redis://broker:6379/0',
      'C_FORCE_ROOT=1',
      "SENTRY_DSN=${sentry_dsn}",
    ],
    command               => 'celery_dashboard worker -Q ipv4,internet',
  }

  ::docker::run { 'dashboard-scheduler':
    image                 => "internetstandards/dashboard:${image_tag}",
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    env                   => [
      "SECRET_KEY=${secret_key}",
      "FIELD_ENCRYPTION_KEY=${field_encryption_key}",
      'ALLOWED_HOSTS=*',
      'DJANGO_DATABASE=production',
      'DB_ENGINE=postgresql_psycopg2',
      'DB_HOST=db',
      'WORKER_ROLE=storage',
      'BROKER=redis://broker:6379/0',
      'C_FORCE_ROOT=1',
      "SENTRY_DSN=${sentry_dsn}",
    ],
    command               => 'celery_dashboard beat -l info --pidfile=/var/tmp/celerybeat.pid',
  }

  ::docker::run { 'db':
    image                 => 'postgres:12',
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
      "SENTRY_DSN=${sentry_dsn}",
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

  # cleanup
  ::docker::run { ['worker', 'scheduler']:
    ensure => absent,
    image  => "internetstandards/dashboard:${image_tag}",
  }

  # scripts and services for application update and db migration
  # by calling update and migration via systemd we automatically
  # get logging to journald and are sure we don't run 2 processes
  # at the same time
  systemd_file::service { 'dashboard-migrate':
    description => 'Run database migrations for dashboard application',
    type        => 'oneshot',
    # override default 'multi-user.target' so this is not started at boot
    wantedby    => [],
    execstart   => '/usr/local/bin/dashboard migrate',
  }
  -> service {'dashboard-migrate':
    enable => true,
  }
  -> file { '/usr/local/bin/dashboard-update':
    content => epp('dashboard/dashboard-update.sh', {
      image_tag=>$image_tag
    }),
    mode    => '0755',
  }
  -> systemd_file::service { 'dashboard-update':
    description => 'Update dashboard application',
    type        => 'oneshot',
    # override default 'multi-user.target' so this is not started at boot
    wantedby    => [],
    execstart   => '/usr/local/bin/dashboard-update',
  }
  -> service {'dashboard-update':
    enable => true,
  }

  file { '/usr/local/bin/dashboard-frontend-update':
    content => epp('dashboard/dashboard-frontend-update.sh', {
      image_tag=>$image_tag
    }),
    mode    => '0755',
  }
  -> systemd_file::service { 'dashboard-frontend-update':
    description => 'Update dashboard frontend container',
    type        => 'oneshot',
    # override default 'multi-user.target' so this is not started at boot
    wantedby    => [],
    execstart   => '/usr/local/bin/dashboard-frontend-update',
  }
  -> service {'dashboard-frontend-update':
    enable => true,
  }

  if $auto_update_interval {
    systemd_file::timer { 'dashboard-update':
      on_boot_sec          => $auto_update_interval,
      on_unit_inactive_sec => $auto_update_interval,
    }
    ~> exec { 'initial trigger dashboard-update timer':
      command     => '/bin/systemctl start dashboard-update.timer',
      refreshonly => true,
    }
  }
}
