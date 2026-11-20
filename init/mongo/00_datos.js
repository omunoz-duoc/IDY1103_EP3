// ============================================================
// Salud Integral 360 · EP2 IDY1103
// 00_datos.js: carga de trazabilidad en MongoDB (se ejecuta al crear el contenedor)
//
// * Generador pseudoaleatorio con semilla fija (mulberry32): mismos datos siempre.
// * Fecha de referencia ("hoy" del caso): 2026-11-02, igual que en PostgreSQL.
// * Solo existe el índice _id: es intencional, para que haya algo que optimizar.
//
// Colecciones:
//   eventos_cita           600.000 documentos
//   registros_call_center  200.000 documentos
// ============================================================

const salud = db.getSiblingDB('salud360');

function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rnd = mulberry32(360);
const pick = (arr) => arr[Math.floor(rnd() * arr.length)];
const pickW = (pares) => {            // [[valor, peso], ...]
  let r = rnd(), acc = 0;
  for (const [v, w] of pares) { acc += w; if (r < acc) return v; }
  return pares[pares.length - 1][0];
};

const REF = new Date('2026-11-02T00:00:00Z').getTime();
const DIA = 86400000;
const LOTE = 10000;

// ---------- eventos_cita ----------
const TIPOS = [['RECORDATORIO_ENVIADO', 0.35], ['CONFIRMACION', 0.30], ['CHECK_IN', 0.18],
               ['ANULACION', 0.10], ['REPROGRAMACION', 0.07]];
const MOTIVOS = [['Paciente enfermo', 0.22], ['Problema de transporte', 0.15], ['Conflicto laboral', 0.18],
                 ['Mejoró su condición', 0.10], ['Error de agenda', 0.08], ['Clínica reprograma', 0.12],
                 ['Sin motivo informado', 0.15]];
const CANALES = [['CALL_CENTER', 0.45], ['WEB', 0.30], ['PRESENCIAL', 0.15], ['SMS', 0.10]];
const ROLES = { CALL_CENTER: 'ejecutivo_call_center', WEB: 'portal_paciente', PRESENCIAL: 'recepcionista', SMS: 'sistema' };

let lote = [];
for (let i = 1; i <= 600000; i++) {
  const tipo = pickW(TIPOS);
  const canal = tipo === 'RECORDATORIO_ENVIADO' ? 'SMS' : pickW(CANALES.filter(c => c[0] !== 'SMS').map(c => [c[0], c[1] / 0.9]));
  const ts = new Date(REF - Math.floor(rnd() * 365 * DIA));
  const doc = {
    cita_id: 1 + Math.floor(rnd() * 500000),
    paciente_id: 1 + Math.floor(rnd() * 50000),
    sede_id: 1 + Math.floor(rnd() * 20),
    tipo: tipo,
    canal: canal,
    ts: ts,
    actor: { rol: ROLES[canal], usuario: canal === 'SMS' ? 'notificador' : 'usr' + String(1 + Math.floor(rnd() * 120)).padStart(3, '0') },
  };
  // El detalle cambia de forma según el tipo de evento (por eso es un documento).
  if (tipo === 'ANULACION') {
    doc.detalle = { motivo: pickW(MOTIVOS), anticipacion_horas: Math.floor(rnd() * 120) };
  } else if (tipo === 'REPROGRAMACION') {
    doc.detalle = { hora_anterior: new Date(ts.getTime() + Math.floor(rnd() * 10) * DIA), dias_desplazamiento: 1 + Math.floor(rnd() * 14) };
  } else if (tipo === 'RECORDATORIO_ENVIADO') {
    doc.detalle = { medio: pick(['SMS', 'WHATSAPP', 'EMAIL']), entregado: rnd() > 0.04 };
  } else if (tipo === 'CHECK_IN') {
    doc.detalle = { minutos_antes: Math.floor(rnd() * 40) - 10, modulo: 'M' + (1 + Math.floor(rnd() * 6)) };
  }
  lote.push(doc);
  if (lote.length === LOTE) { salud.eventos_cita.insertMany(lote, { ordered: false }); lote = []; }
}
if (lote.length) salud.eventos_cita.insertMany(lote, { ordered: false });

// ---------- registros_call_center ----------
const MOTIVOS_LLAMADA = [['RESERVA', 0.40], ['ANULACION', 0.15], ['REPROGRAMACION', 0.15], ['CONSULTA', 0.22], ['RECLAMO', 0.08]];
const RESULTADOS = [['RESUELTO', 0.78], ['DERIVADO', 0.12], ['ABANDONADO', 0.10]];
const NOTAS = ['Paciente solicita hora con especialista', 'Se confirma hora para la próxima semana',
               'Paciente reclama por demora en la atención', 'Consulta por cobertura de previsión',
               'Se anula hora por viaje del paciente', 'Llamada cortada antes de completar la reserva',
               'Se reprograma por agenda del profesional', 'Consulta por resultados de examen'];
lote = [];
for (let i = 1; i <= 200000; i++) {
  const num = 5000000 + (1 + Math.floor(rnd() * 50000)) * 97;
  lote.push({
    ejecutivo: 'ejec' + String(1 + Math.floor(rnd() * 40)).padStart(2, '0'),
    paciente_rut: String(num),
    inicio: new Date(REF - Math.floor(rnd() * 365 * DIA)),
    duracion_seg: 30 + Math.floor(rnd() * 900),
    motivo: pickW(MOTIVOS_LLAMADA),
    resultado: pickW(RESULTADOS),
    notas: pick(NOTAS),
  });
  if (lote.length === LOTE) { salud.registros_call_center.insertMany(lote, { ordered: false }); lote = []; }
}
if (lote.length) salud.registros_call_center.insertMany(lote, { ordered: false });

print('eventos_cita: ' + salud.eventos_cita.countDocuments());
print('registros_call_center: ' + salud.registros_call_center.countDocuments());
