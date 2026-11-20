// 04_after.js · ejecuta la consulta DESPUÉS y muestra su plan
load(__dirname + '/consultas.js');
const sdb = db.getSiblingDB('salud360');
printjson(sdb.eventos_cita.aggregate(pipelineDespues).toArray().slice(0, 10));
printjson(sdb.eventos_cita.explain('executionStats').aggregate(pipelineDespues));
