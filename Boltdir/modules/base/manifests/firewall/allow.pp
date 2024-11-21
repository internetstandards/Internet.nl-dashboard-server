# define allow rule for both protocols
define base::firewall::allow (
  $port = $title,
  $proto = tcp,
) {
  firewall { "100 allow port ${port}/${proto}":
    dport    => $port,
    proto    => $proto,
    jump     => accept,
    protocol => iptables,
  }
  firewall { "100 allow port ${port}/${proto} (ip6tables)":
    dport    => $port,
    proto    => $proto,
    jump     => accept,
    protocol => ip6tables,
  }
}
