plan dashboard::server(
  TargetSpec $nodes,
) {
  # Install puppet on the target and gather facts
  $nodes.apply_prep

  # Compile the manifest block into a catalog
  apply($nodes) {
    include ::base
    include ::dashboard
  }
}
