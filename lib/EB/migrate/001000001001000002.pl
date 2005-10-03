#!/usr/bin/perl

package main;

our $dbh;

package EB::DatabaseMigrator;

use strict;
use warnings;
use EB;
use EB::DB;
use EB::Tools::SQLEngine;

unless ( $dbh ) {
    $dbh = EB::DB->new(trace => $ENV{EB_SQL_TRACE});
    $dbh->connectdb(undef, 1);
}

my $en = EB::Tools::SQLEngine->new(dbh => $dbh, trace => $ENV{EB_SQL_TRACE});
# -- Migratie EekBoek database van versie 1.0.1 (EB 0.10) naar 1.0.2 (EB 0.14).

$en->process(<<EOS);
BEGIN WORK;

-- Add new column.

ALTER TABLE Boekstukken
  ADD COLUMN bsk_open integer;

UPDATE Boekstukken
  SET bsk_open = bsk_amount
  WHERE bsk_paid IS NULL
  AND bsk_dbk_id IN
   ( SELECT dbk_id FROM Dagboeken
       WHERE dbk_type = @{[DBKTYPE_INKOOP]}
       OR dbk_type = @{[DBKTYPE_VERKOOP]} );

UPDATE Boekstukken
  SET bsk_open = 0
  WHERE bsk_paid IS NOT NULL
  AND bsk_dbk_id IN
   ( SELECT dbk_id FROM Dagboeken
       WHERE dbk_type = @{[DBKTYPE_INKOOP]}
       OR dbk_type = @{[DBKTYPE_VERKOOP]} );

ALTER TABLE Boekstukregels
  ADD COLUMN bsr_paid integer REFERENCES Boekstukken;
EOS

my $sth1 = $dbh->sql_exec("SELECT bsk_id,bsk_paid".
			  " FROM Boekstukken".
			  " WHERE bsk_paid IS NOT NULL");

while ( my $rr1 = $sth1->fetchrow_arrayref ) {
    my ($bsk_id, $bsk_paid) = @$rr1;
    warn("Updating bsk:$bsk_id bsr:$bsk_paid\n");
    my $sth2 = $dbh->sql_exec("UPDATE Boekstukregels".
			      " SET bsr_paid = ?".
			      " WHERE bsr_id = ?",
			      $bsk_id, $bsk_paid);
    $sth2->finish;
}

$en->process(<<EOS);
ALTER TABLE Boekstukken
  DROP COLUMN bsk_paid;

-- Bump version.

UPDATE Constants
  SET value = 2
  WHERE name = 'SCM_REVISION';
UPDATE Metadata
  SET adm_scm_revision =
    (SELECT value FROM Constants WHERE name = 'SCM_REVISION');

COMMIT WORK;
EOS

1;
