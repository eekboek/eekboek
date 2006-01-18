-- Script to clean an EekBoek database.

DROP TABLE boekstukregels ;
DROP TABLE journal ;
DROP TABLE boekjaarbalans ;
DROP TABLE metadata ;
DROP TABLE standaardrekeningen ;
DROP TABLE relaties ;
DROP TABLE boekstukken ;
DROP TABLE dagboeken ;
DROP TABLE boekjaren ;
DROP TABLE constants ;
DROP TABLE accounts ;
DROP TABLE btwtabel ;
DROP TABLE verdichtingen ;

CREATE OR REPLACE FUNCTION plpgsql_call_handler() RETURNS language_handler
    AS '$libdir/plpgsql', 'plpgsql_call_handler'
    LANGUAGE c;

CREATE TRUSTED PROCEDURAL LANGUAGE plpgsql HANDLER plpgsql_call_handler;

CREATE OR REPLACE FUNCTION drop_all_sequences() RETURNS INTEGER AS '
DECLARE
 REC record;
BEGIN
 FOR rec IN SELECT relname AS seqname
   FROM pg_class WHERE relkind = ''S'' AND relname LIKE ''bsk_%_seq''
 LOOP
   EXECUTE ''DROP SEQUENCE '' || rec.seqname;
 END LOOP;
 RETURN 1;
END;
' LANGUAGE 'plpgsql';

SELECT * FROM drop_all_sequences();

DROP FUNCTION drop_all_sequences();

DROP PROCEDURAL LANGUAGE plpgsql;

DROP FUNCTION public.plpgsql_call_handler();
