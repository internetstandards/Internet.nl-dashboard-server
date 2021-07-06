# dashboard app, queue and database
class dashboard::app (
  $image_tag = latest,
  $sentry_dsn = undef,
  $auto_update_interval = undef,
  $secret_key,
  $field_encryption_key,
) {
  file { '/usr/local/bin/dashboard':
    source => 'puppet:///modules/dashboard/dashboard.sh',
    mode   => '0755',
  }
  -> ::Docker::Run['dashboard']

  $_hosts = join($dashboard::hosts << "${dashboard::subdomain}.${dashboard::domain}", ',')

  $headers = join([
    # tell browsers to only accept this site over https in the future
    'Strict-Transport-Security:max-age=31536000;includeSubdomains',
    # deny browsers from framing this website
    'X-Frame-Options:DENY',
    # don't let browser guess content types
    'X-Content-Type-Options:nosniff',
    # prevent browser from rendering page if it detects XSS attack
    'X-XSS-Protection:1; mode=block',
    # tell browser to deny any form of framing
    'X-Frame-Options:SAMEORIGIN',
    # don't send any referrer info to third parties
    'Referrer-Policy:same-origin',
    # CSP generated with Mozilla Laboratory after clicking through the site: https://addons.mozilla.org/en-US/firefox/addon/laboratory-by-mozilla/
    # See https://github.com/internetstandards/Internet.nl-dashboard/issues/53
    "Content-Security-Policy:default-src 'none'; connect-src 'self'; font-src 'self'; form-action 'self'; img-src 'self' https://matomo.internet.nl/ data: https://www.internet.nl; script-src 'self' 'unsafe-eval' 'unsafe-inline' https://matomo.internet.nl/piwik.js; style-src 'self' 'unsafe-inline';",
    # only report on sources that would be disallowed by CSP, as currently there is no clear best configuration for our case
    "Content-Security-Policy-Reporting-Only:default-src 'none'; script-src 'self'; connect-src 'self'; img-src 'self'; style-src 'self';",
    # pay respect
    'X-Clacks-Overhead:GNU Terry Pratchett',
    # don't expose version info
    'server:',
  ], '||')

  ::docker::run { 'dashboard-static':
    image                 => "internetstandards/dashboard-static:${image_tag}",
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    labels                => [
      'traefik.enable=true',
      'traefik.frontend.priority=10',
      "traefik.frontend.rule=Host:${_hosts}",
      "\"traefik.frontend.headers.customResponseHeaders=${headers}\"",
    ],
  }

  # all paths that should be routed to Django dynamic backend
  $dynamic_content_paths = [
    '/account/',
    '/admin/',
    '/data/',
    '/jet/',
    '/logout',
    '/mail/',
    '/session/',
    '/static/',
    '/upload/',
  ]

  ::docker::run { 'dashboard':
    image                 => "internetstandards/dashboard:${image_tag}",
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    labels                => [
      'traefik.enable=true',
      'traefik.frontend.priority=20',
      # all dynamic content should be served by Django, otherwise fallback to static content
      "traefik.frontend.rule=\"Host:${_hosts};PathPrefix:${join($dynamic_content_paths,',')}\"",
      "\"traefik.frontend.headers.customResponseHeaders=${headers}\"",
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
      'WORKER_ROLE=default',
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
      'WORKER_ROLE=default',
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
      'WORKER_ROLE=default',
      'BROKER=redis://broker:6379/0',
      'C_FORCE_ROOT=1',
      "SENTRY_DSN=${sentry_dsn}",
    ],
    command               => 'celery_dashboard worker -Q ipv4,ipv6,4and6,internet',
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
      'WORKER_ROLE=default',
      'BROKER=redis://broker:6379/0',
      'C_FORCE_ROOT=1',
      "SENTRY_DSN=${sentry_dsn}",
    ],
    command               => 'celery_dashboard beat -l info --pidfile=/var/tmp/celerybeat.pid',
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
