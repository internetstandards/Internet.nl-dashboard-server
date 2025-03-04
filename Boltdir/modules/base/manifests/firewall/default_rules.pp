# default firewall rules
define base::firewall::default_rules (
  $admin_ip_whitelist,
  $provider = $title,
) {
  $icmp = $provider ? {
    iptables => icmp,
    ip6tables => 'ipv6-icmp',
  }
  $local = $provider ? {
    iptables => '127.0.0.1/8',
    ip6tables => '::1/128',
  }

  # Default firewall rules
  firewall { "000 accept all icmp (${provider})":
    proto    => $icmp,
    jump     => 'accept',
    protocol => $provider,
  }
  -> firewall { "001 accept all to lo interface (${provider})":
    proto    => 'all',
    iniface  => 'lo',
    jump     => 'accept',
    protocol => $provider,
  }
  -> firewall { "002 reject local traffic not on loopback interface (${provider})":
    iniface     => '! lo',
    proto       => 'all',
    destination => $local,
    jump        => 'reject',
    protocol    => $provider,
  }
  -> firewall { "003 accept related established rules (${provider})":
    proto    => 'all',
    state    => ['RELATED', 'ESTABLISHED'],
    jump     => 'accept',
    protocol => $provider,
  }
  -> firewall_multi { "010 SSH admin whitelist (${provider})":
    source   => $admin_ip_whitelist[$provider],
    dport    => 22,
    proto    => tcp,
    jump     => accept,
    protocol => $provider,
  }
  -> firewall { "999 drop all (${provider})":
    proto    => 'all',
    jump     => 'drop',
    before   => undef,
    protocol => $provider,
  }
}
