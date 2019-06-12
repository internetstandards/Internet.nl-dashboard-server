# configure dashboard application stack
class dashboard (
  $bofh_email = 'test@example.com',
  $domain = 'internet.test',
  $subdomain = 'dashboard',
  $le_staging = true,
){
  class { '::docker':
    # TODO: don't let docker mess with firewall
    # iptables => false,
  }

  docker_network { 'dashboard':
    ensure => present,
  } -> Docker::Run <| |>

  # external facing webserver
  class { '::dashboard::ingress': }

  # application, queue, database
  class { '::dashboard::app': }
}
