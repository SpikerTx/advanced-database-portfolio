#!/usr/bin/env bash
# Drops the local database created by setup_local.sh (destructive).
set -euo pipefail
DB_NAME="${DB_NAME:-access_pensions}"
read -r -p "Drop database ${DB_NAME}? [y/N] " ans
[ "$ans" = "y" ] && dropdb --if-exists "${DB_NAME}" && echo "Dropped ${DB_NAME}."
