-- Migratie EekBoek database van versie 1.0.6 naar 1.0.7 (0.37).

BEGIN WORK;

-- Nieuwe constante om aan te geven of the Kosten/Omzet codering gebruikt
-- mag worden.

INSERT INTO Constants (name, value) VALUES ('KO_OK', '0');

-- Bump version.

UPDATE Constants SET value = 7 WHERE name = 'SCM_REVISION';
UPDATE Metadata
  SET adm_scm_revision =
	( SELECT int2(value) FROM Constants WHERE name = 'SCM_REVISION' );

COMMIT WORK;
