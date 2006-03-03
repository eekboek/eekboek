-- Migratie EekBoek database van versie 1.0.7 naar 1.0.8 (EB 0.43).
-- THIS FILE IS GENERATED FROM 001000007001000008.m4. DO NOT MODIFY.

BEGIN WORK;

-- Table Accounts
ALTER TABLE ONLY Accounts ADD COLUMN temp int8;
UPDATE Accounts SET temp = acc_ibalance;
ALTER TABLE ONLY Accounts DROP COLUMN acc_ibalance;
ALTER TABLE ONLY Accounts RENAME COLUMN temp TO acc_ibalance;

ALTER TABLE ONLY Accounts ADD COLUMN temp int8;
UPDATE Accounts SET temp = acc_balance;
ALTER TABLE ONLY Accounts DROP COLUMN acc_balance;
ALTER TABLE ONLY Accounts RENAME COLUMN temp TO acc_balance;

-- Table Boekstukken
ALTER TABLE ONLY Boekstukken ADD COLUMN temp int8;
UPDATE Boekstukken SET temp = bsk_amount;
ALTER TABLE ONLY Boekstukken DROP COLUMN bsk_amount;
ALTER TABLE ONLY Boekstukken RENAME COLUMN temp TO bsk_amount;

ALTER TABLE ONLY Boekstukken ADD COLUMN temp int8;
UPDATE Boekstukken SET temp = bsk_open;
ALTER TABLE ONLY Boekstukken DROP COLUMN bsk_open;
ALTER TABLE ONLY Boekstukken RENAME COLUMN temp TO bsk_open;

ALTER TABLE ONLY Boekstukken ADD COLUMN temp int8;
UPDATE Boekstukken SET temp = bsk_saldo;
ALTER TABLE ONLY Boekstukken DROP COLUMN bsk_saldo;
ALTER TABLE ONLY Boekstukken RENAME COLUMN temp TO bsk_saldo;

-- Table Boekstukregels
ALTER TABLE ONLY Boekstukregels ADD COLUMN temp int8;
UPDATE Boekstukregels SET temp = bsr_amount;
ALTER TABLE ONLY Boekstukregels DROP COLUMN bsr_amount;
ALTER TABLE ONLY Boekstukregels RENAME COLUMN temp TO bsr_amount;

-- Table Journal
ALTER TABLE ONLY Journal ADD COLUMN temp int8;
UPDATE Journal SET temp = jnl_amount;
ALTER TABLE ONLY Journal DROP COLUMN jnl_amount;
ALTER TABLE ONLY Journal RENAME COLUMN temp TO jnl_amount;

-- Table Boekjaarbalans
ALTER TABLE ONLY Boekjaarbalans ADD COLUMN temp int8;
UPDATE Boekjaarbalans SET temp = bkb_balance;
ALTER TABLE ONLY Boekjaarbalans DROP COLUMN bkb_balance;
ALTER TABLE ONLY Boekjaarbalans RENAME COLUMN temp TO bkb_balance;

-- Bump version.

UPDATE Constants
  SET value = 8
  WHERE name = 'SCM_REVISION';
UPDATE Metadata
  SET adm_scm_revision =
	(SELECT int4(value) FROM Constants WHERE name = 'SCM_REVISION');

COMMIT WORK;
