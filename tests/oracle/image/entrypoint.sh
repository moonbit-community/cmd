#!/bin/sh
set -eu
umask 022
export LANG=C
export LC_ALL=C
export TZ=UTC
export PATH=/oracle/bin
exec "$@"
