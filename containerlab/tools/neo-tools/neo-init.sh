#!/bin/sh
# Container start: make ssh host keys, then run the command (default: sleep forever).
mkdir -p /run/sshd
ssh-keygen -A >/dev/null 2>&1
exec "$@"
