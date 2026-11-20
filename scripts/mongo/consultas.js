// ============================================================
// consultas.js · consulta extra en MongoDB (la cargan los demás scripts)
// Negocio: ¿por qué motivos se anulan horas en cada sede en los últimos
// 30 días? La revisan a diario el analista de operaciones y el supervisor
// del call center.
// ============================================================
const DESDE = new Date('2026-10-03T00:00:00Z');   // 30 días antes de la fecha de referencia
const HASTA = new Date('2026-11-02T00:00:00Z');   // fecha de referencia del caso

// ANTES: calcula el día de cada evento con $addFields y filtra sobre ese campo
// calculado. Un campo calculado no está en ningún índice, así que el filtro de
// fecha se evalúa documento por documento.
const pipelineAntes = [
  { $addFields: { dia: { $dateTrunc: { date: '$ts', unit: 'day' } } } },
  { $match: { tipo: 'ANULACION', dia: { $gte: DESDE, $lt: HASTA } } },
  { $group: { _id: { sede_id: '$sede_id', motivo: '$detalle.motivo' }, anulaciones: { $sum: 1 } } },
  { $sort: { '_id.sede_id': 1, anulaciones: -1, '_id.motivo': 1 } },
];

// DESPUÉS: $match directo sobre los campos guardados (tipo y ts) como primera
// etapa. Mismo resultado, porque DESDE y HASTA son medianoche.
// Apoyo: índice compuesto { tipo: 1, ts: 1 } (igualdad primero, rango después).
const pipelineDespues = [
  { $match: { tipo: 'ANULACION', ts: { $gte: DESDE, $lt: HASTA } } },
  { $group: { _id: { sede_id: '$sede_id', motivo: '$detalle.motivo' }, anulaciones: { $sum: 1 } } },
  { $sort: { '_id.sede_id': 1, anulaciones: -1, '_id.motivo': 1 } },
];
