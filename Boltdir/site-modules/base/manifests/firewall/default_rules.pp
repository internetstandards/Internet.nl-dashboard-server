# default firewall rules
define base::firewall::default_rules (
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
    action   => 'accept',
    provider => $provider,
  }
  -> firewall { "001 accept all to lo interface (${provider})":
    proto    => 'all',
    iniface  => 'lo',
    action   => 'accept',
    provider => $provider,
  }
  -> firewall { "002 reject local traffic not on loopback interface (${provider})":
    iniface     => '! lo',
    proto       => 'all',
    destination => $local,
    action      => 'reject',
    provider    => $provider,
  }
  -> firewall { "003 accept related established rules (${provider})":
    proto    => 'all',
    state    => ['RELATED', 'ESTABLISHED'],
    action   => 'accept',
    provider => $provider,
  }
  -> firewall { "010 Allow inbound SSH (${provider})":
    dport    => 22,
    proto    => tcp,
    action   => accept,
    provider => $provider,
  }
  -> firewall { "999 drop all (${provider})":
    proto    => 'all',
    action   => 'drop',
    before   => undef,
    provider => $provider,
  }
}
