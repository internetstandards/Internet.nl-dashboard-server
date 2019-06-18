plan dashboard::server(
  TargetSpec $nodes,
  Boolean $noop=false,
) {
  # Install puppet on the target and gather facts
  $nodes.apply_prep

  # Compile the manifest block into a catalog
  apply($nodes, _noop => $noop) {
    include ::base
    include ::dashboard
  }
}
