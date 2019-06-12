#!/bin/bash

if ! test "$(whoami)" == "root";then
  echo "Error: must run as root! Login as root user or use sudo: sudo su -"
  exit 1
fi

exec docker exec \
    $(tty -s && echo '-ti') \
    dashboard \
    dashboard "$@"
