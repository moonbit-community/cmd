#!/bin/sh
set -eu
umask 022
# Docker ENV supplies defaults; explicit fixture values must reach the oracle.
exec "$@"
