class dashboard::ctlssa (
    $version = '603673bf61eb32503d77d24f0a28509d8e76dca2',
    $secret_key = $dashboard::app::secret_key,
    $allowlist = $base::firewall::admin_ip_whitelist,
) {
    include vcsrepo::manage::git

    $ctlssa_hostnames = join($dashboard::app::_hosts, ",")
    $sourcerange = join($allowlist['iptables'] + $allowlist['ip6tables'], ',')

    class {'docker::compose':
        ensure  => present,
    }

    vcsrepo { '/opt/internetnl-ctlssa/':
        ensure     => present,
        provider   => git,
        source     => 'https://github.com/internetstandards/Internet.nl-ct-log-subdomain-suggestions-api.git',
        revision   => $version,
        submodules => true,
    } ~> Docker_compose['internetnl-ctlssa']

    file { '/opt/internetnl-ctlssa/compose-local.yml':
        content => @("END")
        services:
            app:
                labels:
                    - "traefik.enable=true"
                    - 'traefik.http.routers.ctlssa.rule=${dashboard::app::hostrules} && PathPrefix(`/ctlssa`)'
                    - "traefik.http.routers.ctlssa.entrypoints=websecure"
                    - "traefik.http.middlewares.local-only-allowlist.ipallowlist.sourcerange=172.16.0.0/12"
                    - "traefik.http.routers.ctlssa.middlewares=local-only-allowlist"
                environment:
                    - CTLSSA_HOSTNAMES=${ctlssa_hostnames}
                    - SECRET_KEY=${secret_key}
            app-ingest:
                # limit nr of cpus this application can use to prevent OS resource starvation
                cpu_count: 1
                environment:
                    - SECRET_KEY=${secret_key}
            certstream:
                labels:
                    - "traefik.enable=true"
                    - 'traefik.http.routers.certstream-metrics.rule=${dashboard::app::hostrules} && Path(`/certstream/metrics`)'
                    - "traefik.http.routers.certstream-metrics.entrypoints=websecure"
                    - "traefik.http.middlewares.admin-allowlist.ipallowlist.sourcerange=${sourcerange}"
                    - "traefik.http.middlewares.certstream-metrics-path.replacepath.path=/metrics"
                    - "traefik.http.routers.certstream-metrics.middlewares=admin-allowlist,certstream-metrics-path"
                    - "traefik.http.services.certstream-metrics.loadbalancer.server.port=8080"
                # limit nr of cpus this application can use to prevent OS resource starvation
                cpu_count: 1

        |END
    } ~> Docker_compose['internetnl-ctlssa']

    docker_compose { 'internetnl-ctlssa':
        ensure        => present,
        compose_files => ['/opt/internetnl-ctlssa/compose.yml', '/opt/internetnl-ctlssa/compose-local.yml'],
    }
}
