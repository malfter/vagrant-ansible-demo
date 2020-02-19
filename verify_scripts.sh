#!/usr/bin/env sh

export SHELLCHECK_OPTS="-e SC2029 -e SC2119 -e SC2006 -e SC2045 -e SC2143 -e SC2120 -e SC2059 -e SC2002 -e SC2086"

find . \
  -path .git -type d -prune -o \
  -type f -name "*.sh" \
  -print0 |
  xargs -0 -r -n1 shellcheck -C

