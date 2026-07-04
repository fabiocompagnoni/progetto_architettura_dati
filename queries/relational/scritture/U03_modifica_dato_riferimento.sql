-- U03 — Riclassifica un tipo voce: aggiorna la categoria nel catalogo.
\if :{?codice_voce} \else \set codice_voce '0401' \endif
\if :{?categoria}   \else \set categoria 'WELFARE' \endif

UPDATE tipo_voce
SET categoria = :'categoria'
WHERE codice = :'codice_voce';
