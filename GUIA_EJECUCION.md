# Guía de ejecución · EP2 Salud Integral 360

Este proyecto levanta PostgreSQL 18 y MongoDB 8.0 en Docker, carga datos sintéticos del caso Salud Integral 360, mide 3 consultas críticas de PostgreSQL y 1 consulta extra de MongoDB antes y después de optimizarlas, y deja todas las evidencias en `evidencias/<fecha_hora>/`. No hay pasos manuales: un solo comando hace todo en 1 a 3 minutos.

## 1. Requisitos

- Docker Desktop (Windows o macOS) o Docker Engine con el plugin `docker compose` (Linux).
- Docker con al menos 4 CPU y 6 GB de RAM asignados. Cada base de datos usa 2 CPU y 2 GB, fijos. En Docker Desktop se ajusta en *Settings → Resources*.
- Puertos 5432 y 27017 libres (se pueden cambiar, ver sección 8).
- Unos 2 GB libres en disco para las imágenes.

No hace falta instalar PostgreSQL, MongoDB, `psql` ni `mongosh`: todo corre dentro de los contenedores.

## 2. Ejecutar

Desde la carpeta del proyecto:

| Sistema | Comando |
| --- | --- |
| Linux, macOS o Git Bash en Windows | `./ejecutar.sh` |
| Windows (PowerShell) | `powershell -ExecutionPolicy Bypass -File .\ejecutar.ps1` |

El script hace lo siguiente, en orden:

1. Crea la carpeta `evidencias/<fecha_hora>/` y guarda los datos del equipo y de Docker.
2. Borra contenedores y datos de una ejecución anterior y los recrea desde cero. Los datos se generan con semilla fija, así que siempre son los mismos.
3. Espera a que termine la carga inicial (unos 25 s en PostgreSQL y 20 s en MongoDB).
4. Corre `runner-pg`, que mide las 3 consultas de PostgreSQL en 4 escenarios, aplica los índices y genera la comparación.
5. Corre `runner-mongo`, que hace lo mismo con la consulta extra de MongoDB.

Al terminar verás `==> Listo. Evidencias en evidencias/<fecha_hora>/`. Las bases quedan encendidas para revisarlas (sección 4).

Alternativa sin script: `docker compose up` también hace todo, pero las evidencias quedan en `evidencias/manual/`, sin datos del equipo anfitrión, y no borra datos de ejecuciones anteriores. Detén todo con Ctrl+C.

## 3. Qué evidencias se generan

| Archivo | Contenido | Punto de la pauta |
| --- | --- | --- |
| `00_ambiente_host.txt` | Sistema, CPU y RAM del equipo, versión de Docker y límites reales de cada contenedor | Condiciones de la medición |
| `00_ambiente.md` | Versión exacta de cada motor, CPU, límites de CPU y RAM vistos por el motor, configuración de PostgreSQL y tamaño de los datos | Condiciones de la medición |
| `01_verificacion.txt` | `COUNT(*)` de pacientes, citas y prestaciones por cita (equivalen a customers, orders y order_items), más el resto de las tablas y colecciones | 1.3 Verificación de carga |
| `planes/qN_A_antes.txt` | SQL completo y `EXPLAIN (ANALYZE, BUFFERS)` de la consulta original sin índices | 2.2 Línea base ANTES, 3 Congestión |
| `planes/qN_D_despues.txt` | SQL optimizado y su plan, ya con índices | 5 Medición DESPUÉS |
| `planes/qN_B_*.txt`, `planes/qN_C_*.txt` | Planes de los escenarios intermedios: solo reescritura y solo índices | 4 Aporte de cada optimización |
| `planes/*.json` | Los mismos planes en JSON, para herramientas como explain.dalibo.com | Evidencia complementaria |
| `03_optimizaciones.log` | Cada `CREATE INDEX` y `ANALYZE` ejecutado, con su tiempo | 4 Implementación |
| `tiempos.csv`, `tiempos_mongo.csv` | Cada corrida individual: tiempo, costo, buffers, filas y operaciones del plan | 2.2 y 5 Promedio de 3 |
| `comparacion.md` | Tablas antes vs después, cambio en el plan, aporte de cada optimización y costo de los índices | 5.2 Comparación obligatoria |

Los 4 escenarios que se miden por consulta son:

| Escenario | Consulta | Índices | Para qué sirve |
| --- | --- | --- | --- |
| A | Original | No | Línea base ANTES |
| B | Reescrita | No | Aporte de la reescritura por sí sola |
| C | Original | Sí | Aporte de los índices por sí solos |
| D | Reescrita | Sí | Resultado DESPUÉS |

Cada escenario se ejecuta 1 vez para calentar la caché y luego 3 veces medidas. Además, el runner calcula un md5 del resultado de la consulta original y de la optimizada, para comprobar que devuelven exactamente las mismas filas (columna "Mismo resultado").

## 4. Revisar las bases con pgAdmin o MongoDB Compass

| | PostgreSQL | MongoDB |
| --- | --- | --- |
| Host | `localhost` | `localhost` |
| Puerto | `5432` | `27017` |
| Base de datos | `salud360` | `salud360` |
| Usuario | `dba` | `dba` |
| Contraseña | `Salud360_dba` | `Salud360_dba` |
| Cadena de conexión | `postgresql://dba:Salud360_dba@localhost:5432/salud360` | `mongodb://dba:Salud360_dba@localhost:27017/salud360?authSource=admin` |

Después de una ejecución completa, la base ya tiene los índices de la EP2. Los resultados de todas las mediciones quedan también en la tabla `medicion.resultados` de PostgreSQL.

## 5. Ejecutar partes a mano

Todos los scripts están montados en `/scripts` dentro de los contenedores.

| Qué | Comando |
| --- | --- |
| Volver al estado ANTES (sin índices) | `docker compose exec postgres psql -U dba -d salud360 -f /scripts/postgres/99_revertir.sql` |
| Ver los planes ANTES | `docker compose exec postgres psql -U dba -d salud360 -f /scripts/postgres/02_explain_before.sql` |
| Aplicar las optimizaciones | `docker compose exec postgres psql -U dba -d salud360 -f /scripts/postgres/03_optimizaciones.sql` |
| Ver los planes DESPUÉS | `docker compose exec postgres psql -U dba -d salud360 -f /scripts/postgres/05_explain_after.sql` |
| Ejecutar solo las consultas | `01_consultas_before.sql` y `04_consultas_after.sql`, igual que arriba |
| MongoDB, plan ANTES | `docker compose exec mongo mongosh -u dba -p Salud360_dba --authenticationDatabase admin /scripts/mongo/01_before.js` |
| MongoDB, crear índice / revertir / plan DESPUÉS | lo mismo con `03_optimizaciones.js`, `99_revertir.js` o `04_after.js` |
| Repetir solo las mediciones, sin recrear datos | `docker compose run --rm runner-pg` y luego `docker compose run --rm --no-deps runner-mongo` |

El texto de cada consulta está en un solo lugar, `scripts/postgres/consultas/qN_antes.sql` y `qN_despues.sql`, y en `scripts/mongo/consultas.js`. Los scripts 01 a 05 y el runner lo leen desde ahí, así que lo que se mide es siempre lo mismo que se documenta.

## 6. Estructura del proyecto

```
ejecutar.sh / ejecutar.ps1   punto de entrada
docker-compose.yml           2 bases + 2 runners, recursos y configuración fijos
.env.example                 valores que se pueden cambiar (copiar como .env)
init/postgres/               esquema (00) y datos (01), se cargan al crear el contenedor
init/mongo/                  datos de trazabilidad (eventos_cita, registros_call_center)
scripts/postgres/            00 verificación, 01 a 05 de la pauta, 99 revertir, consultas/
scripts/mongo/               consultas.js, 01_before, 03_optimizaciones, 04_after, 99_revertir
runner/                      medición automática, ambiente y armado de comparacion.md
evidencias/                  una carpeta por ejecución
RESUMEN_EVIDENCIAS.md        explicación breve de los resultados
```

## 7. Reiniciar desde cero o apagar

- Apagar y borrar los datos de las bases: `docker compose down -v`. Las evidencias en `evidencias/` no se borran.
- Volver a medir desde cero: ejecutar de nuevo `./ejecutar.sh` o `ejecutar.ps1`. Cada ejecución crea una carpeta nueva.

## 8. Problemas comunes

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| `port is already allocated` | Ya hay un PostgreSQL o MongoDB local usando el puerto | Copiar `.env.example` como `.env` y cambiar `PG_PORT` o `MONGO_PORT` |
| Un contenedor termina con código 137 | Docker tiene menos memoria que la necesaria | Subir la RAM de Docker Desktop a 6 GB o más |
| `bash\r: No such file or directory` al correr `ejecutar.sh` | El archivo se guardó con fin de línea de Windows | Usar `ejecutar.ps1`, o convertir con `dos2unix ejecutar.sh` |
| PowerShell no deja ejecutar el script | Política de ejecución | Usar el comando con `-ExecutionPolicy Bypass` de la sección 2 |
| Los tiempos son distintos a los de `RESUMEN_EVIDENCIAS.md` | Otro procesador u otra carga en el equipo | Es esperable. Lo que debe repetirse es la tendencia, los planes y los buffers, que no dependen del equipo |
| `evidencias/` queda con archivos de `root` en Linux | Se usó `docker compose up` directo | Usar `./ejecutar.sh`, que corre los runners con tu usuario |

Para tiempos más estables, cierra programas pesados mientras corre la medición y evita ejecutar con el equipo en modo ahorro de energía.
