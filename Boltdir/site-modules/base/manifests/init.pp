# provide application independent OS layer base settings
class base (
  $ipv6_address = undef,
  $ipv6_gateway = undef,
){
  $osinfo = $::os['distro']['description']
  notice("fqdn=${::fqdn}, env=${::environment}, os=${osinfo}")

  class { '::base::firewall': }

  class { '::accounts': }

  # enable apt unattended security upgrades
  class { '::unattended_upgrades':
    # reboot outside of office hours if security updates require this
    auto => {
      reboot      => true,
      reboot_time => '20:00',
    }
  }

  # utility packages
  ensure_packages([
    'sl', 'atop', 'htop', 'unzip', 'jq',
    'cron', 'curl', 'net-tools', 'ncdu', 'tcpdump',
  ])

  # sudo
  sudo::conf { 'sudo':
    priority => 10,
    content  => '%sudo   ALL=(ALL) NOPASSWD: ALL',
  }
  sudo::conf { 'vagrant':
    priority => 10,
    content  => '%vagrant   ALL=(ALL) NOPASSWD: ALL',
  }

  file_line {'sudo prompt':
    path     => '/etc/bash.bashrc',
    line     => "PS1='\${debian_chroot:+(\$debian_chroot)}super_\$(logname)@\\h:\\w\\$ '",
    match    => 'PS1=',
    multiple => false,
  }

  # enable ntp
  class { '::ntp':
      servers => [
          '0.pool.ntp.org', '1.pool.ntp.org',
          '2.pool.ntp.org', '3.pool.ntp.org'
      ],
  }

  # enable ssh server
  class { '::ssh':
    storeconfigs_enabled => false,
    server_options       => {
      # improve ssh server security
      'PasswordAuthentication' => no,
      'PermitRootLogin'        => no,
    }
  }

  # remind superusers of configurationmanagement
  file {
      '/etc/sudoers.lecture':
            content => "THIS HOST IS MANAGED BY PUPPET. Please only make permanent changes\nthrough puppet and do not expect manual changes to be maintained!\nMore info: https://gitlab.com/internet-cleanup-foundation/server\n\n";
  }
  -> sudo::conf { 'lecture':
    priority => 10,
    content  => "Defaults\tlecture=\"always\"\nDefaults\tlecture_file=\"/etc/sudoers.lecture\"\n",
  }

  swap_file::files { 'default':
      ensure   => present,
  }

  # IPv6
  class {'network': }

  network::interface { $::networking['primary']:
    enable_dhcp => true,
  }

  if $ipv6_address {
    # configure static ipv6 address
    network::interface { "${::networking['primary']}_v6":
      auto      => false,
      interface => $::networking['primary'],
      family    => inet6,
      ipaddress => $ipv6_address,
      gateway   => $ipv6_gateway,
    }
    # accepting router advertisements causes the static default gateway
    # to be dropped after a while
    sysctl { 'net.ipv6.conf.all.accept_ra':
      value => '0',
    }
  }
}
