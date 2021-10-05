# dashboard app, queue and database
class dashboard::monitoring (
  $whitelist = $base::firewall::admin_ip_whitelist,
  $headers = $dashboard::app::headers,
) {
  $_hosts = $dashboard::hosts << "${dashboard::subdomain}.${dashboard::domain}"

  $hosts = join(suffix(prefix($_hosts, '"'), '"'),", ")

  $sourcerange = join($whitelist['iptables'], ",")

  ::docker::run { 'monitoring':
    image                 => 'quay.io/prometheus/node-exporter',
    tag                   => latest,
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    labels                => concat([
      'traefik.enable=true',
      "traefik.http.middlewares.admin-whitelist-monitoring.ipwhitelist.sourcerange=${sourcerange}",
      "traefik.http.routers.monitoring.rule='Host(${hosts}) && PathPrefix(\"/metrics\")'",
      'traefik.http.routers.monitoring.priority=30',
      'traefik.http.routers.monitoring.tls=true',
      "traefik.http.routers.monitoring.tls.certResolver=letsencrypt",
      'traefik.http.routers.monitoring.middlewares=admin-whitelist-monitoring',
    ], prefix($headers, "traefik.http.middlewares.monitoring.headers.customresponseheaders.")),

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
