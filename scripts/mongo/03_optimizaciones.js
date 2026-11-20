// 03_optimizaciones.js · índice compuesto para la consulta extra
// Regla ESR (Equality, Sort, Range): primero el campo de igualdad (tipo) y
// después el de rango (ts). Así el índice entrega solo las anulaciones del
// período, sin leer el resto de los 600.000 eventos.
db.getSiblingDB('salud360').eventos_cita.createIndex({ tipo: 1, ts: 1 }, { name: 'ix_eventos_tipo_ts' });
