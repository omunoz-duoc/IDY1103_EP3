// ============================================================
// runner_mongo.js · genera las evidencias de la consulta extra en MongoDB
//   Escenarios (igual que en PostgreSQL):
//     A = pipeline original sin índice (ANTES)   B = solo reescritura
//     C = solo índice                            D = reescritura + índice (DESPUÉS)
//   Cada escenario: 1 ejecución de calentamiento + 3 medidas + explain("executionStats").
// ============================================================
const fs = require('fs');
load('/scripts/mongo/consultas.js');

const RUN_ID = process.env.RUN_ID || 'manual';
const OUT = '/evidencias/' + RUN_ID;
const PLANES = OUT + '/planes';
fs.mkdirSync(PLANES, { recursive: true });

const sdb = db.getSiblingDB('salud360');
const col = sdb.eventos_cita;
const log = (m) => print('[runner-mongo ' + new Date().toISOString().substring(11, 19) + '] ' + m);

// Recorre el explain y junta métricas, venga en el formato que venga
// (motor clásico o SBE, con o sin etapas $cursor).
function resumirExplain(ex) {
  const r = { docs: 0, keys: 0, etapas: [] };
  const agregar = (e) => { if (!r.etapas.includes(e)) r.etapas.push(e); };
  // Etapas del plan ganador del motor de consultas (COLLSCAN, IXSCAN, FETCH, GROUP...)
  function etapasPlan(p) {
    if (Array.isArray(p)) return p.forEach(etapasPlan);
    if (!p || typeof p !== 'object') return;
    ['queryPlan', 'inputStage', 'inputStages', 'outerStage', 'innerStage'].forEach((x) => p[x] && etapasPlan(p[x]));
    if (p.stage) agregar(p.stage + (p.indexName ? ' (' + p.indexName + ')' : ''));
  }
  (function walk(o, k) {
    if (!o || typeof o !== 'object') return;
    if (Array.isArray(o)) {
      // Etapas del pipeline que quedaron fuera del motor ($addFields, $group, ...)
      return o.forEach((x) => {
        walk(x);
        if (k === 'stages' && x && typeof x === 'object') Object.keys(x).filter((y) => y.startsWith('$') && y !== '$cursor').forEach(agregar);
      });
    }
    if (k === 'executionStats' && o.totalDocsExamined !== undefined) {
      r.docs += Number(o.totalDocsExamined);
      r.keys += Number(o.totalKeysExamined);
      return;                                   // no entrar a las etapas internas de ejecución
    }
    if (k === 'winningPlan') { etapasPlan(o); return; }
    Object.keys(o).forEach((key) => walk(o[key], key));
  })(ex);
  r.etapas = r.etapas.join(' → ');
  return r;
}

const resultados = [];
function medir(escenario, pipeline, archivo) {
  col.aggregate(pipeline).toArray();                         // calentamiento
  const res = col.aggregate(pipeline).toArray();
  const huella = JSON.stringify(res);
  const ex = col.explain('executionStats').aggregate(pipeline);
  const m = resumirExplain(ex);
  const tiempos = [];
  for (let i = 1; i <= 3; i++) {
    const t0 = Date.now();
    col.aggregate(pipeline).toArray();
    tiempos.push(Date.now() - t0);
  }
  fs.writeFileSync(PLANES + '/' + archivo + '.json', JSON.stringify({ pipeline: pipeline, explain: ex }, null, 2));
  const fila = {
    escenario, tiempos,
    prom: tiempos.reduce((a, b) => a + b, 0) / tiempos.length,
    min: Math.min(...tiempos), max: Math.max(...tiempos),
    docs: m.docs, keys: m.keys, etapas: m.etapas,
    filas: res.length, huella,
  };
  resultados.push(fila);
  log(`Escenario ${escenario}: ${fila.prom.toFixed(1)} ms, docs examinados ${fila.docs}, claves ${fila.keys}`);
  return fila;
}

log('Esperando datos...');
while (col.estimatedDocumentCount() < 600000) sleep(2000);

load('/scripts/mongo/99_revertir.js');                       // estado ANTES garantizado

// ---------- Ambiente ----------
const bi = sdb.adminCommand({ buildInfo: 1 });
const hi = sdb.adminCommand({ hostInfo: 1 });
const ss = sdb.adminCommand({ serverStatus: 1 });
const stats = sdb.runCommand({ collStats: 'eventos_cita' });
const amb = [
  '', '## MongoDB', '',
  '| Parámetro | Valor |', '| --- | --- |',
  `| Versión | ${bi.version} |`,
  `| CPU | ${hi.extra && hi.extra.cpuString ? hi.extra.cpuString : 'no informado'} (${hi.system.numCores} núcleos visibles) |`,
  `| RAM visible / límite (MB) | ${hi.system.memSizeMB} / ${hi.system.memLimitMB} |`,
  `| Caché WiredTiger configurada | ${(ss.wiredTiger.cache['maximum bytes configured'] / 1048576).toFixed(0)} MB |`,
  `| Sistema | ${hi.os.name} ${hi.os.version} |`,
  `| eventos_cita | ${stats.count} documentos, ${(stats.size / 1048576).toFixed(1)} MB de datos |`,
  `| registros_call_center | ${sdb.registros_call_center.estimatedDocumentCount()} documentos |`,
  '',
];
fs.appendFileSync(OUT + '/00_ambiente.md', amb.join('\n'));
fs.appendFileSync(OUT + '/01_verificacion.txt',
  `\nMongoDB\n  eventos_cita:          ${col.countDocuments()}\n  registros_call_center: ${sdb.registros_call_center.countDocuments()}\n`);

// ---------- Mediciones ----------
const A = medir('A', pipelineAntes, 'mongo_A_antes');
medir('B', pipelineDespues, 'mongo_B_solo_reescritura');
log('Aplicando 03_optimizaciones.js');
load('/scripts/mongo/03_optimizaciones.js');
medir('C', pipelineAntes, 'mongo_C_solo_indice');
const D = medir('D', pipelineDespues, 'mongo_D_despues');

// ---------- Salidas ----------
const csv = ['escenario,corrida,tiempo_ms,docs_examinados,claves_examinadas,etapas'];
resultados.forEach((r) => r.tiempos.forEach((t, i) => csv.push(`${r.escenario},${i + 1},${t},${r.docs},${r.keys},"${r.etapas}"`)));
fs.writeFileSync(OUT + '/tiempos_mongo.csv', csv.join('\n') + '\n');

const idx = sdb.runCommand({ collStats: 'eventos_cita' }).indexSizes;
const f = (n) => n.toFixed(1);
const md = [
  '', '# Consulta extra en MongoDB', '',
  'Tiempo = duración de `aggregate().toArray()` medida desde el cliente, promedio de 3 corridas después de 1 de calentamiento. Documentos y claves examinados salen de `explain("executionStats")`.', '',
  '| Consulta | ANTES prom. ms (mín–máx) | DESPUÉS prom. ms (mín–máx) | Mejora | Docs examinados antes → después | Claves examinadas antes → después | Grupos | Mismo resultado |',
  '| --- | --- | --- | --- | --- | --- | --- | --- |',
  `| Anulaciones por sede y motivo | ${f(A.prom)} (${A.min}–${A.max}) | ${f(D.prom)} (${D.min}–${D.max}) | ${f(100 * (A.prom - D.prom) / A.prom)}% | ${A.docs} → ${D.docs} | ${A.keys} → ${D.keys} | ${D.filas} | ${A.huella === D.huella ? 'sí' : 'NO'} |`,
  '', '| Escenario | Prom. ms | Docs examinados | Claves examinadas | Etapas del plan |', '| --- | --- | --- | --- | --- |',
  ...resultados.map((r) => `| ${{ A: 'A: original sin índice (ANTES)', B: 'B: solo reescritura', C: 'C: solo índice', D: 'D: reescritura + índice (DESPUÉS)' }[r.escenario]} | ${f(r.prom)} | ${r.docs} | ${r.keys} | ${r.etapas} |`),
  '', `Tamaño de índices en eventos_cita: ${Object.entries(idx).map(([k, v]) => `${k} = ${(v / 1048576).toFixed(1)} MB`).join(', ')}.`, '',
];
fs.appendFileSync(OUT + '/comparacion.md', md.join('\n'));
log('Listo');
