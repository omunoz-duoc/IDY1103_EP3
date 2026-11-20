# Ambiente de ejecución · 2026-11-20_231137

Generado automáticamente el 2026-11-20 23:12:05 UTC. Los datos del equipo anfitrión y de Docker están en `00_ambiente_host.txt` (los genera ejecutar.sh / ejecutar.ps1).

## PostgreSQL

| Parámetro | Valor |
| --- | --- |
| Versión | PostgreSQL 18.7 (Debian 18.7-1.pgdg13+5) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit |
| CPU del servidor | Intel(R) Xeon(R) Processor @ 2.10GHz |
| Núcleos visibles | 4 |
| Límite de CPU del contenedor (cgroup; 200000 100000 = 2 CPU) | v1: cuota 200000 / periodo 100000 |
| Límite de RAM del contenedor (cgroup, bytes) | 2147483648 |
| RAM total visible | 16473744 kB |
| autovacuum | on |
| effective_cache_size | 1GB |
| jit | off |
| max_connections | 100 |
| max_parallel_workers_per_gather | 0 |
| random_page_cost | 4 |
| shared_buffers | 512MB |
| track_io_timing | on |
| work_mem | 4MB |

### Tamaño de los datos

| Tabla | Filas (estimadas) | Tamaño total |
| --- | --- | --- |
| cita_prestaciones | 975948 | 77 MB |
| citas | 500000 | 56 MB |
| pagos | 279204 | 25 MB |
| pacientes | 50000 | 7480 kB |
| prestaciones | 2000 | 264 kB |
| profesionales | 400 | 88 kB |
| especialidades | 12 | 80 kB |
| sedes | 20 | 64 kB |

Base de datos completa: 173 MB.

Kernel visto desde el contenedor: `Linux 6.18.44-fc-v726 x86_64`

## MongoDB

| Parámetro | Valor |
| --- | --- |
| Versión | 8.0.38 |
| CPU | Intel(R) Xeon(R) Processor @ 2.10GHz (4 núcleos visibles) |
| RAM visible / límite (MB) | 16087 / 2048 |
| Caché WiredTiger configurada | 1024 MB |
| Sistema | Ubuntu 24.04 |
| eventos_cita | 600000 documentos, 121.9 MB de datos |
| registros_call_center | 200000 documentos |
