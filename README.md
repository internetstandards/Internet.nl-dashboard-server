# Internet.nl Dashboard server configuration

## Compulsory reading

- https://puppet.com/blog/introducing-masterless-puppet-bolt
- https://puppet.com/docs/bolt/latest/bolt_project_directories.html#local-project-directory
- https://puppet.com/docs/bolt/latest/bolt_project_directories.html#project-directory-structure
- https://puppet.com/docs/bolt/latest/inventory_file.html
- https://puppet.com/docs/bolt/latest/bolt_installing_modules.html#install-modules

## Testing server configuration

    vagrant up
    make test
    vagrant ssh

## Applying server configuration

    make apply

To only one host:

    make apply node=acc.dashboard.internet.nl
