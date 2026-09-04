#!/bin/sh
set -eu
export LANG=C
export LC_ALL=C
export PATH=/oracle/bin

base64 --version | head -n1
cmp --version | head -n1
find --version | head -n1
xargs --version | head -n1
grep --version | head -n1
wget --version | head -n1
curl --version | head -n1
make --version | head -n1
jq --version
xxd -v 2>&1
printf 'sh oracle: POSIX.1-2024 via '
printf '%s\n' 'dash 0.5.12 (source sha256 0d632f6b945058d84809cac7805326775bd60cb4a316907d0bd4228ff7107154)'
printf '%s\n' 'jqlog oracle: bobzhang/jqlog@0.1.0 06a529211343c773d30d2c3aa0231a2456665b7a'
