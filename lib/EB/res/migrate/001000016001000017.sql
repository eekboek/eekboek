BEGIN WORK;

-- Niewe tabel voor bijlagen.

CREATE TABLE Attachments (
    att_id   		 int primary key,
    att_name		 text NOT NULL,
    att_size		 int NOT NULL,
    att_encoding	 smallint,
    att_content		 text
);
CREATE SEQUENCE attachments_id_seq;
ALTER SEQUENCE attachments_id_seq OWNED BY Attachments.att_id;

-- Foreign key toevoegen in Boekstukken tabel.

ALTER TABLE Boekstukken ADD COLUMN bsk_att INT REFERENCES Attachments;

-- Bump version.

UPDATE Constants
  SET value = '17'
  WHERE name = 'SCM_REVISION' AND value = '16';
UPDATE Metadata
  SET adm_scm_revision =
    (SELECT int2(value) FROM Constants WHERE name = 'SCM_REVISION');

COMMIT WORK;
