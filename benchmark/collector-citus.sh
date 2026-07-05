#!/bin/bash
# Misura una query su Citus raccogliendo i contatori per-nodo: azzera pg_stat_statements su tutti i nodi, esegue la query, poi legge i delta da ogni nodo con run_command_on_all_nodes. Da eseguire sul coordinator.
set -euo pipefail
qfile=${1:?serve il file della query}
container=${CITUS_CONTAINER:-citus}
run() { docker exec -i "$container" psql -U postgres -d archdata -q "$@"; }

run -tAc "SELECT run_command_on_all_nodes('SELECT pg_stat_statements_reset()')" >/dev/null

start=$(date +%s%3N)
run -f - < "$qfile" >/dev/null
end=$(date +%s%3N)
echo "latenza wall-clock: $((end - start)) ms"
echo

run -c "
SELECT n.nodename AS nodo,
       CASE WHEN n.groupid = 0 THEN 'coordinator' ELSE 'worker' END AS ruolo,
       (r.result::json->>'righe')::bigint    AS righe,
       (r.result::json->>'exec_ms')::numeric AS exec_ms,
       (r.result::json->>'cache')::bigint    AS blk_cache,
       (r.result::json->>'disco')::bigint    AS blk_disco,
       (r.result::json->>'wal')::bigint      AS wal_bytes
FROM run_command_on_all_nodes(\$\$
       SELECT json_build_object(
         'righe',   coalesce(sum(rows), 0),
         'exec_ms', round(coalesce(sum(total_exec_time), 0)::numeric, 1),
         'cache',   coalesce(sum(shared_blks_hit), 0),
         'disco',   coalesce(sum(shared_blks_read), 0),
         'wal',     coalesce(sum(wal_bytes), 0))
       FROM pg_stat_statements
       WHERE query NOT ILIKE '%pg_stat_statements%'
         AND query NOT ILIKE '%run_command_on_all_nodes%'
     \$\$) r
JOIN pg_dist_node n ON n.nodeid = r.nodeid
ORDER BY n.groupid;"