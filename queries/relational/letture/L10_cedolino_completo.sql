-- L10 — Cedolino completo (intestazione + voci, ratei, contributi, addizionali, giorni) per (dipendente, periodo).
\if :{?tenant} \else \set tenant 1 \endif
\if :{?dip}    \else \set dip 1 \endif
\if :{?anno}   \else \set anno 2026 \endif
\if :{?mese}   \else \set mese 6 \endif

SELECT jsonb_build_object(
           'anno',              c.anno,
           'mese',              c.mese,
           'data_elaborazione', c.data_elaborazione,
           'tot_competenze',    c.tot_competenze,
           'tot_trattenute',    c.tot_trattenute,
           'netto',             c.netto,
           'costo_azienda',     c.costo_azienda,
           'tfr_fondo',         c.tfr_fondo,

           'voci', (
               SELECT jsonb_agg(jsonb_build_object(
                          'riga',     v.riga,
                          'tipo',     v.tipo_voce_codice,
                          'quantita', v.quantita,
                          'importo',  v.importo
                      ) ORDER BY v.riga)
               FROM voce_cedolino v
               WHERE v.tenant_id = c.tenant_id AND v.cedolino_id = c.cedolino_id
           ),

           'ratei', (
               SELECT jsonb_agg(jsonb_build_object(
                          'tipo',      r.tipo,
                          'spettante', r.spettante,
                          'goduto',    r.goduto,
                          'residuo',   r.residuo
                      ))
               FROM rateo r
               WHERE r.tenant_id = c.tenant_id AND r.cedolino_id = c.cedolino_id
           ),

           'contributi', (
               SELECT jsonb_agg(jsonb_build_object(
                          'tipo',             co.tipo_contributo_codice,
                          'imponibile',       co.imponibile,
                          'aliquota',         co.aliquota,
                          'quota_dipendente', co.quota_dipendente,
                          'quota_ditta',      co.quota_ditta
                      ))
               FROM contributo co
               WHERE co.tenant_id = c.tenant_id AND co.cedolino_id = c.cedolino_id
           ),

           'addizionali', (
               SELECT jsonb_agg(jsonb_build_object(
                          'tipo',       a.tipo,
                          'imponibile', a.imponibile,
                          'aliquota',   a.aliquota,
                          'importo',    a.importo
                      ))
               FROM addizionale a
               WHERE a.tenant_id = c.tenant_id AND a.cedolino_id = c.cedolino_id
           ),

           'giorni', (
               SELECT jsonb_agg(jsonb_build_object(
                          'data',              g.data,
                          'tipo',              g.tipo_giorno,
                          'ore_lavorate',      g.ore_lavorate,
                          'ore_straordinario', g.ore_straordinario,
                          'timbrature', (
                              SELECT jsonb_agg(jsonb_build_object(
                                         'progressivo', t.progressivo,
                                         'entrata',     t.ora_entrata,
                                         'uscita',      t.ora_uscita
                                     ) ORDER BY t.progressivo)
                              FROM timbratura t
                              WHERE t.tenant_id   = g.tenant_id
                                AND t.cedolino_id = g.cedolino_id
                                AND t.data        = g.data
                          )
                      ) ORDER BY g.data)
               FROM giorno g
               WHERE g.tenant_id = c.tenant_id AND g.cedolino_id = c.cedolino_id
           )
       ) AS cedolino_completo
FROM cedolino c
WHERE c.tenant_id = :tenant
  AND c.dipendente_id = :dip
  AND c.anno = :anno
  AND c.mese = :mese;
