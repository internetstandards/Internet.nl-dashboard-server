# Internet.nl Dashboard server configuration

## Compulsory reading

- https://puppet.com/blog/introducing-masterless-puppet-bolt
- https://puppet.com/docs/bolt/latest/bolt_project_directories.html#local-project-directory
- https://puppet.com/docs/bolt/latest/bolt_project_directories.html#project-directory-structure
- https://puppet.com/docs/bolt/latest/inventory_file.html
- https://puppet.com/docs/bolt/latest/bolt_installing_modules.html#install-modules

## Testing server configuration on local virtual machine

    make lab

Machine will be available at ip: http://172.30.1.5

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
