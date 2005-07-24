-- BTW Tariefgroepen

COPY BTWTariefgroepen (btg_id, btg_desc, btg_acc_verkoop, btg_acc_inkoop) FROM stdin;
0	BTW Geen	\N	\N
1	BTW Hoog	1500	1520
2	BTW Laag	1510	1530
\.

-- BTW Tabel

COPY BTWTabel (btw_id, btw_desc, btw_perc, btw_incl, btw_tariefgroep) FROM stdin;
0	BTW Geen	0	t	0
1	BTW 19% incl.	1900	t	1
2	BTW 19% excl.	1900	f	1
3	BTW 6,0% incl.	600	t	2
4	BTW 6,0% excl.	600	f	2
\.

