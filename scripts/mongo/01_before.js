// 01_before.js · ejecuta la consulta ANTES y muestra su plan
// Uso: mongosh "mongodb://USUARIO:CLAVE@localhost:27017/salud360?authSource=admin" scripts/mongo/01_before.js
load(__dirname + '/consultas.js');
const sdb = db.getSiblingDB('salud360');
printjson(sdb.eventos_cita.aggregate(pipelineAntes).toArray().slice(0, 10));
printjson(sdb.eventos_cita.explain('executionStats').aggregate(pipelineAntes));
