class dashboard::ctlssa (
    $version = 'main',
    $secret_key = $dashboard::app::secret_key,
) {
    include vcsrepo::manage::git

    $ctlssa_hostnames = join($dashboard::app::_hosts, ",")

    class {'docker::compose':
        ensure  => present,
    }

    vcsrepo { '/opt/internetnl-ctlssa/':
        ensure   => present,
        provider => git,
        source   => 'https://github.com/internetstandards/Internet.nl-ct-log-subdomain-suggestions-api.git',
        revision => $version,
    } ~> Docker_compose['internetnl-ctlssa']

    file { '/opt/internetnl-ctlssa/compose-local.yml':
        content => @("END")
        services:
            app:
                labels:
                    - "traefik.enable=true"
                    - 'traefik.http.routers.ctlssa.rule=Host(${dashboard::app::hosts}) && PathPrefix(`/ctlssa`)'
                    - "traefik.http.routers.ctlssa.entrypoints=websecure"
                    - "traefik.http.middlewares.local-only-whitelist.ipwhitelist.sourcerange=172.16.0.0/12"
                    - "traefik.http.routers.ctlssa.middlewares=local-only-whitelist"
                environment:
                    - CTLSSA_HOSTNAMES=${ctlssa_hostnames}
                    - SECRET_KEY=${secret_key}
            app-ingest:
                environment:
                    - SECRET_KEY=${secret_key}

        |END
    } ~> Docker_compose['internetnl-ctlssa']

    docker_compose { 'internetnl-ctlssa':
        ensure        => present,
        compose_files => ['/opt/internetnl-ctlssa/compose.yml', '/opt/internetnl-ctlssa/compose-local.yml'],
    }
}
