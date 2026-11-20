-- Ambiente del servidor PostgreSQL (lo genera runner_pg.sh en 00_ambiente.md)
\pset format unaligned
\pset tuples_only on
SELECT '## PostgreSQL';
SELECT '';
SELECT '| Parámetro | Valor |';
SELECT '| --- | --- |';
SELECT '| Versión | ' || version() || ' |';
SELECT '| CPU del servidor | ' || COALESCE((regexp_match(pg_read_file('/proc/cpuinfo'), 'model name\s*:\s*([^\n]+)'))[1], 'no informado') || ' |';
SELECT '| Núcleos visibles | ' || (SELECT count(*) FROM regexp_matches(pg_read_file('/proc/cpuinfo'), '^processor', 'gn')) || ' |';
SELECT '| Límite de CPU del contenedor (cgroup; 200000 100000 = 2 CPU) | ' || COALESCE(btrim(pg_read_file('/sys/fs/cgroup/cpu.max', true), E' \n'), 'v1: cuota ' || btrim(pg_read_file('/sys/fs/cgroup/cpu/cpu.cfs_quota_us', true), E' \n') || ' / periodo ' || btrim(pg_read_file('/sys/fs/cgroup/cpu/cpu.cfs_period_us', true), E' \n'), 'no disponible') || ' |';
SELECT '| Límite de RAM del contenedor (cgroup, bytes) | ' || COALESCE(btrim(pg_read_file('/sys/fs/cgroup/memory.max', true), E' \n'), btrim(pg_read_file('/sys/fs/cgroup/memory/memory.limit_in_bytes', true), E' \n'), 'no disponible') || ' |';
SELECT '| RAM total visible | ' || (regexp_match(pg_read_file('/proc/meminfo'), 'MemTotal:\s*([^\n]+)'))[1] || ' |';
SELECT '| ' || name || ' | ' || current_setting(name) || ' |'
FROM pg_settings
WHERE name IN ('shared_buffers','work_mem','effective_cache_size','jit','max_parallel_workers_per_gather',
               'random_page_cost','track_io_timing','autovacuum','max_connections')
ORDER BY name;
SELECT '';
SELECT '### Tamaño de los datos';
SELECT '';
SELECT '| Tabla | Filas (estimadas) | Tamaño total |';
SELECT '| --- | --- | --- |';
SELECT '| ' || c.relname || ' | ' || c.reltuples::BIGINT || ' | ' || pg_size_pretty(pg_total_relation_size(c.oid)) || ' |'
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC;
SELECT '';
SELECT 'Base de datos completa: ' || pg_size_pretty(pg_database_size(current_database())) || '.';
