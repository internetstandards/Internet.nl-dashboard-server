# Apply security patched and reboot system
plan base::security_hotfix(
  TargetSpec $nodes,
) {
  run_command('unattended-upgrade', $nodes, '_catch_errors' => true)

  run_plan('reboot', nodes=> $nodes, reconnect_timeout => 300)

  return run_task('service', $nodes, {
    'name'   => 'docker-dashboard',
    'action' => 'status',
  })
}
