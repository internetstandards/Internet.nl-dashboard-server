# Internet.nl Dashboard server configuration

This repository contains infrastructure and server configuration for the Internet.nl Dashboard application.

## Applying server configuration on live servers

This will ensure the server configuration (OS, middleware, etc) is brought in line with the expected configuration in `Boltdir/`.

    make provision_staging

Or for the production server:

    make provision_live

## Updating the Dashboard application from latest image on Docker hub

This will update the Dashboard application itself and leave server configuration alone. It will pull in the latest version of the application from Docker Hub and restart all required application components (frontend, worker, etc) to ensure they are up to date.

### Staging

Make sure the desired version of image `internetstandards/dashboard:latest` is pushed to Docker hub.

    make promote_latest_to_staging
    make update_staging

Or combined:

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
