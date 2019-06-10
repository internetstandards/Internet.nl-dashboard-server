#!/bin/bash

set -xe

cd /srv/dashboard/compose/

docker exec -ti dashboard_dashboard_1 dashboard "$@"