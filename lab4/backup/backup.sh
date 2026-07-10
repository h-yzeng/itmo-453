#!/bin/sh
# Lab 4 automated backup. Archives each named volume to /backups with a
# timestamp, then applies a keep-last-seven retention policy per volume.
set -eu

VOLUMES="grafana-data prometheus-data kuma-data ssh-config"
TS=$(date +%Y%m%d-%H%M%S)
DEST=/backups

for v in $VOLUMES; do
    tar czf "$DEST/$v-$TS.tar.gz" -C "/vol/$v" .
done

for v in $VOLUMES; do
    ls -1t "$DEST"/"$v"-*.tar.gz 2>/dev/null | tail -n +8 | while read -r old; do
        rm -f "$old"
    done
done

echo "[$TS] backup complete: $VOLUMES"
