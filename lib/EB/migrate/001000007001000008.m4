-- Migratie EekBoek database van versie 1.0.7 naar 1.0.8 (EB 0.43).
-- THIS FILE IS GENERATED FROM 001000007001000008.m4. DO NOT MODIFY.

BEGIN WORK;

define(`docol',`ALTER TABLE ONLY $1 ADD COLUMN temp int8;
UPDATE $1 SET temp = $2;
ALTER TABLE ONLY $1 DROP COLUMN $2;
ALTER TABLE ONLY $1 RENAME COLUMN temp TO $2;
')dnl
-- Table Accounts
docol(Accounts, acc_ibalance)
docol(Accounts, acc_balance)
-- Table Boekstukken
docol(Boekstukken, bsk_amount)
docol(Boekstukken, bsk_open)
docol(Boekstukken, bsk_saldo)
-- Table Boekstukregels
docol(Boekstukregels, bsr_amount)
-- Table Journal
docol(Journal, jnl_amount)
-- Table Boekjaarbalans
docol(Boekjaarbalans, bkb_balance)
-- Bump version.

UPDATE Constants
  SET value = 8
  WHERE name = 'SCM_REVISION';
UPDATE Metadata
  SET adm_scm_revision =
	(SELECT int4(value) FROM Constants WHERE name = 'SCM_REVISION');

COMMIT WORK;
