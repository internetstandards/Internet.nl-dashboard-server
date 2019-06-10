# Basic firewall security
class base::firewall {
  class { '::ufw': }

  # allow ssh in
  ufw::allow { 'allow-ssh-from-all':
    port => 22,
  }

  # rate limit incoming ssh
  ufw::limit { '22': }
}
