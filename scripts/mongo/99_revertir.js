// 99_revertir.js · vuelve al estado ANTES (sin el índice de la EP2)
const c = db.getSiblingDB('salud360').eventos_cita;
if (c.getIndexes().some(i => i.name === 'ix_eventos_tipo_ts')) c.dropIndex('ix_eventos_tipo_ts');
