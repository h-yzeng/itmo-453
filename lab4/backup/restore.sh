#!/bin/sh
# Lab 4 restore. Usage: restore.sh <timestamp>
# Example: restore.sh 20260710-020000
# Stop the app containers first, run this, then start them again.
set -eu

if [ $# -ne 1 ]; then
    echo "usage: restore.sh <timestamp>"
    exit 1
fi

TS=$1
VOLUMES="grafana-data prometheus-data kuma-data ssh-config"

for v in $VOLUMES; do
    A="/backups/$v-$TS.tar.gz"
    if [ ! -f "$A" ]; then
        echo "missing archive: $A"
        exit 1
    fi
done

for v in $VOLUMES; do
    find "/vol/$v" -mindepth 1 -delete
    tar xzf "/backups/$v-$TS.tar.gz" -C "/vol/$v"
    echo "restored $v from $TS"
done

echo "restore complete, start the app containers again"
