-- Dagboeken

COPY Dagboeken FROM stdin;
1	Kas	4	1000
4	Postbank	3	1120
6	Inkoop	1	1600
7	Verkoop	2	1200
8	Memoriaal	5	\N
\.

-- Sequences for Boekstuknummers, one for each Dagboek

CREATE SEQUENCE bsk_nr_1_seq;
CREATE SEQUENCE bsk_nr_4_seq;
CREATE SEQUENCE bsk_nr_6_seq;
CREATE SEQUENCE bsk_nr_7_seq;
CREATE SEQUENCE bsk_nr_8_seq;

