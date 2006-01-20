-- Migratie EekBoek database van versie 1.0.5 (EB 0.20) naar 1.0.6 (0.32).

BEGIN WORK;

-- Nieuw kolom voor boekstuk saldo.
-- Nodig voor decode / export.

ALTER TABLE Boekstukken ADD COLUMN bsk_saldo int;

-- Fix foutief teken van adm_relatie / verkoop boekingen.
-- Nodig voor decode / export.

UPDATE Boekstukregels
SET bsr_amount = -bsr_amount
WHERE bsr_id IN
  ( SELECT bsr_id
    FROM Boekstukregels, Boekstukken, Dagboeken
    WHERE bsr_date <=
      ( SELECT bky_end
        FROM Boekjaren
	WHERE bky_code = '<<<<' )
    AND bsr_bsk_id = bsk_id
    AND bsk_dbk_id = dbk_id
    AND dbk_type = 2 );

-- Bump version.

UPDATE Constants SET value = 6 WHERE name = 'SCM_REVISION';
UPDATE Metadata  SET adm_scm_revision = 6;

COMMIT WORK;
