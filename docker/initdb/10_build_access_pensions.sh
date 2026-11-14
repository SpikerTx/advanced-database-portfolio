#!/usr/bin/env bash
# Runs once, on first start of the primary: builds the full Access Pensions database from the repository scripts
export PGUSER="$POSTGRES_USER" PGDATABASE="$POSTGRES_DB"
bash /repo/scripts/build_database.sh
