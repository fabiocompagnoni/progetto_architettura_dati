#!/bin/bash
# Crea il .pgpass usato da Citus per l'auth nodo-nodo (il coordinator si connette ai worker come postgres). Gira in docker-entrypoint-initdb.d al primo avvio, come utente postgres -> proprietario e permessi 600 corretti (altrimenti libpq lo ignora). Persiste nel volume montato su /var/lib/postgresql.
set -euo pipefail
umask 077
printf '*:5432:*:%s:%s\n' "$POSTGRES_USER" "$POSTGRES_PASSWORD" > /var/lib/postgresql/.pgpass
chmod 600 /var/lib/postgresql/.pgpass