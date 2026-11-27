#!/bin/sh
# Container start: make this container's own ssh host keys (the image holds none), then run the command (default: sleep forever).
# ssh-keygen -A only creates keys that are missing, so a restarted container keeps the keys it made at its first start.
# flock: a lab file may run the same command (see the ssh labs). The lock makes the second caller wait until all keys exist.
mkdir -p /run/sshd
flock /run/neo-keygen.lock ssh-keygen -A >/dev/null 2>&1
exec "$@"
