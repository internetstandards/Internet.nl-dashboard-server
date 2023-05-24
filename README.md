# Internet.nl Dashboard server configuration

This repository contains infrastructure and server configuration for the Internet.nl Dashboard application.

## TL;DR
Latest image is made during CI steps.

Docker images are here: https://hub.docker.com/r/internetstandards/dashboard/tags

### To production:
```shell
make promote_latest_to_staging
make promote_staging_to_live
make update_live
```

or
```shell
make promote_latest_to_staging
make promote_staging_to_live

ssh dashboard.internet.nl
sudo su -
/usr/local/bin/dashboard-update
```


## Applying server configuration on live servers

This will ensure the server configuration (OS, middleware, etc) is brought in line with the expected configuration in `Boltdir/`.

    make apply_staging

Or for the production server:

    make apply_live

Instead of directly applying the changes you can opt to run a noop apply first be issuing for example:

    make plan_live

## Updating the Dashboard application from latest image on Docker hub

This will update the Dashboard application itself and leave server configuration alone. It will pull in the latest version of the application from Docker Hub and restart all required application components (frontend, worker, etc) to ensure they are up to date.

### Staging auto Continuous Deployment

Staging server is configured to automatically watch for changes to the Docker image `internetstandards/dashboard:latest` on Docker Hub. It will automatically pull in the latest image and restart required services.

Auto update is configured using Systemd. The `dashboard-update.service` oneshot unit executes the `/usr/local/bin/dashboard-update` script. This script will check for and pull in the latest Docker image and restart services in required.

The `dashboard-update.timer` unit is configured to trigger the `dashboard-update.service` unit every 5 minutes.

To view logging from the update process run `journalctl -u dashboard-update.service` or `journalctl -u dashboard-update.service -f` for live tailing.

To temporary disable auto update (until next reboot) run: `systemctl stop dashboard-update.timer`.

To see when the timer last activated and when it will activate next run: `systemctl list-timers`.

### Manual staging deploy

Make sure the desired version of image `internetstandards/dashboard:latest` is pushed to Docker hub.

    make update_staging

### Manual live deploy

    make promote_staging_to_live
    make update_live

## Maintenance

### Security updates

Security patches are applied automatically every day. If a reboot is required (eg: kernel update) this will be automatically performed at 20:00.

To manually trigger an security hotfix and potential immediate reboot run:

    bolt plan run base::security_hotfix --nodes staging

### Database upgrades

When upgrading to a newer version of Postgres DB please use the following procedure:

- Before starting make sure there is enough disk space to contain a second copy of the current database:

        df -h /srv/dashboard/
        du -sch /srv/dashboard/db/

- On the staging server `acc.dashboard.internet.nl` (as root):

        systemctl stop docker-db
        cd /srv/dashboard
        mv db db<OLD_VERSION>
        docker run -ti --rm \
          -v /srv/dashboard/db<OLD_VERSION>:/var/lib/postgresql/<OLD_VERSION>/data \
          -v /srv/dashboard/db<NEW_VERSION>:/var/lib/postgresql/<NEW_VERSION>/data \
          tianon/postgres-upgrade:<OLD_VERSION>-to-<NEW_VERSION>
        mv db<NEW_VERSION> db

- Update Postgresql Docker image version in `Boldir/modules/dashboard/manifests/app.pp`
- Make a staging deployment (`make apply_staging`)
- Verify functionality https://acc.dashboard.internet.nl/
- Repeat for live

See also: https://github.com/tianon/docker-postgres-upgrade

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
