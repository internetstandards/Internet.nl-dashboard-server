# Basic firewall security
class base::firewall (
  $admin_ip_whitelist,
){
  class { '::firewall': }

  # purge all unmanaged rules
  resources { 'firewall':
    purge => true,
  }

  # default default rules for both protocols
  base::firewall::default_rules { ['iptables', 'ip6tables']:
    admin_ip_whitelist => $admin_ip_whitelist,
  }
}
