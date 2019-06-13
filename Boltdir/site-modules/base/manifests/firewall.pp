# Basic firewall security
class base::firewall {
  class { '::firewall': }

  # purge all unmanaged rules
  resources { 'firewall':
    purge => true,
  }

  # default default rules for both protocols
  base::firewall::default_rules { ['iptables', 'ip6tables']: }
}
