#!/usr/bin/env bash
set -euo pipefail

host=mongo:27017

already_initiated() {
  mongosh --quiet --host "$host" --eval 'rs.status().ok' 2>/dev/null | grep -q '^1$'
}

if already_initiated; then
  exit 0
fi

mongosh --quiet --host "$host" --eval "rs.initiate({_id: 'rs0', members: [{_id: 0, host: '$host'}]})"
