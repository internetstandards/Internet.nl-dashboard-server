# Internet.nl Dashboard server configuration

## Applying server configuration on live servers

    make live

Or staging:

    make staging

## Updating Dashboard application from latest image on Docker hub

### Staging

Make sure the desired version of image `internetstandards/dashboard:latest` is pushed to Docker hub.

    make promote_latest_to_staging
    make update_staging

Or:

    make promote_latest_to_staging update_staging

### Live

    make promote_staging_to_live
    make update_live

## Development compulsory reading

- https://puppet.com/blog/introducing-masterless-puppet-bolt
- https://puppet.com/docs/bolt/latest/bolt_project_directories.html#local-project-directory
- https://puppet.com/docs/bolt/latest/bolt_project_directories.html#project-directory-structure
- https://puppet.com/docs/bolt/latest/inventory_file.html
- https://puppet.com/docs/bolt/latest/bolt_installing_modules.html#install-modules

## Testing server configuration on local virtual machine

Run the follow command to setup a local VM as testserver and provision it. Or update the provisioning if the server already exists.

    make lab

Server will be available at ip: https://172.30.1.5

Traefik dashboard: http://172.30.1.5:8000

### Testsuite

To validate the local VM against the testsuite (`spec/*.rb`) run:

    make test
