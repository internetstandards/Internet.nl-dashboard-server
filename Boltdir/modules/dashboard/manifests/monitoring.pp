# dashboard app, queue and database
class dashboard::monitoring (
  $whitelist = $base::firewall::admin_ip_whitelist,
) {
  $_hosts = $dashboard::hosts << "${dashboard::subdomain}.${dashboard::domain}"

  $hosts = join(suffix(prefix($_hosts, '"'), '"'),', ')

  $sourcerange = join($whitelist['iptables'] + $whitelist['ip6tables'], ',')

  ::docker::run { 'monitoring':
    image                 => 'quay.io/prometheus/node-exporter',
    tag                   => latest,
    systemd_restart       => always,
    net                   => dashboard,
    health_check_interval => 60,
    labels                => [
      'traefik.enable=true',
      "traefik.http.routers.monitoring.rule=Host(${hosts}) && PathPrefix(\"/metrics\")",
      'traefik.http.routers.monitoring.entrypoints=websecure',
      "traefik.http.middlewares.admin-whitelist-monitoring.ipwhitelist.sourcerange=${sourcerange}",
      'traefik.http.routers.monitoring.middlewares=admin-whitelist-monitoring',
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
