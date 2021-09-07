# dashboard app, queue and database
class dashboard::monitoring (
  $whitelist = $base::firewall::admin_ip_whitelist,
) {
  $_hosts = join($dashboard::hosts << "${dashboard::subdomain}.${dashboard::domain}", ',')

  $headers = join([
    # tell browsers to only accept this site over https in the future
    'Strict-Transport-Security:max-age=31536000;includeSubdomains',
    # deny browsers from framing this website
    'X-Frame-Options:DENY',
    # don't let browser guess content types
    'X-Content-Type-Options:nosniff',
    # prevent browser from rendering page if it detects XSS attack
    'X-XSS-Protection:1;mode=block',
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

  ::docker::run { 'monitoring':
    image                 => 'quay.io/prometheus/node-exporter',
    tag                   => latest,
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    labels                => [
      'traefik.enable=true',
      'traefik.frontend.priority=30',
      "traefik.frontend.rule=\"Host:${_hosts};PathPrefix:/metrics\"",
      "\"traefik.frontend.headers.customResponseHeaders=${headers}\"",
    ],

    command               => join([
      '--path.rootfs=/host',
      '--collector.textfile.directory=/host/var/tmp/node-exporter-textfiles',
      '--collector.systemd',
      # disable metrics about the exporter itself
      '--web.disable-exporter-metrics',
    ],' '),
    privileged            => true,
    extra_parameters      => '--pid=host --user=root',
    volumes               => [
      '/:/host:ro,rslave',
      '/var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket',
    ],
  }
}
