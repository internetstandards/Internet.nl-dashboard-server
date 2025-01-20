# provide application independent OS layer base settings
class base (
  $ipv6_address = undef,
  $ipv6_gateway = undef,
){
  $osinfo = $::os['distro']['description']
  notice("fqdn=${::fqdn}, env=${::environment}, os=${osinfo}")

  class { '::base::firewall': }

  class { '::accounts': }

  class{ '::systemd': }

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

  # enable ssh server
  class { '::ssh':
    storeconfigs_enabled => false,
    server_options       => {
      # improve ssh server security
      'PasswordAuthentication' => no,
      'PermitRootLogin'        => no,
      'DebianBanner'           => no,
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

  # IPv6
  class {'network': }

  # puppet-networking module does not handle ipv6 properly, managing /etc/network/interfaces files manually
  # because else we need to switch to systemd-networkd or something
  file { "/etc/network/interfaces":
      content => @("END")
      source /etc/network/interfaces.d/*
      auto ${::networking['primary']} lo
      allow-hotplug ${::networking['primary']}
      iface ${::networking['primary']} inet dhcp
      iface lo inet loopback
      |END
  }

  if $ipv6_address {
    file { "/etc/network/interfaces.d/${::networking['primary']}_ipv6.conf":
        content => @("END")
        iface ens3 inet6 static
          address ${ipv6_address}
        |END
    }

    # fix ipv6 autoconf for because Docker enables forwarding, but this system
    # should not be treated as a ipv6 router
    # https://www.mattb.net.nz/blog/2011/05/12/linux-ignores-ipv6-router-adverti
    # sements-when-forwarding-is-enabled/
    sysctl { 'net.ipv6.conf.all.accept_ra':
      value => '2',
    }
    sysctl { 'net.ipv6.conf.all.autoconf':
      value => '1',
    }
    sysctl { 'net.ipv6.conf.default.accept_ra':
      value => '2',
    }
    sysctl { 'net.ipv6.conf.default.autoconf':
      value => '1',
    }
    sysctl { "net.ipv6.conf.${::networking['primary']}.accept_ra":
      value => '2',
    }
    sysctl { "net.ipv6.conf.${::networking['primary']}.autoconf":
      value => '1',
    }

    # hack to make sure above accept_ra are reapplied after docker is started
    # and has messed up everything IPv6
    File['/etc/systemd/system/docker.service.d']
    -> file { '/etc/systemd/system/docker.service.d/ipv6-hack-fix.conf':
      ensure  => present,
      content => "[Service]\nExecStartPost=/sbin/sysctl --system\n",
    }
    ~> Exec['docker-systemd-reload-before-service']
  }
}
