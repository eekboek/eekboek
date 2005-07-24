-- Hoofdverdichtingen

COPY Verdichtingen (vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct) FROM stdin;
1	Vaste Activa	t	t	\N
2	Vlottende activa	t	t	\N
3	Eigen vermogen	t	t	\N
4	Vreemd vermogen	t	t	\N
5	Bedrijfsopbrengsten	f	t	\N
6	Personeelslasten	f	t	\N
7	Afschrijvingen	f	t	\N
9	Financiële baten & lasten	f	t	\N
\.

-- Verdichtingen

COPY Verdichtingen (vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct) FROM stdin;
11	Immateriële vaste activa	t	t	1
12	Materiële vaste activa	t	t	1
13	Financiële vaste activa	t	t	1
21	Handelsvoorraden	t	t	2
22	Vorderingen	t	t	2
23	Effecten	t	t	2
24	Liquide middelen	t	t	2
25	Tussenrekeningen	t	t	2
31	Kapitaal	t	t	3
41	Kredietinstellingen lang	t	t	4
44	Overige schulden lang	t	t	4
46	Leveranciers kredieten	t	t	4
48	Belastingen & soc. lasten	t	t	4
49	Overige schulden kort	t	t	4
51	Netto omzet	f	f	5
52	Kostprijs van de omzet	f	t	5
53	Overige bedrijfsopbrengst	f	t	5
60	Lonen en salarissen	f	t	6
61	Sociale lasten	f	t	6
62	Overige personeelskosten	f	t	6
63	Afschrijving materiele vaste activa	f	t	6
64	Afschrijving immateriele vaste activa	f	t	7
65	Huisvestingskosten	f	t	6
66	Autokosten	f	t	6
67	Verkoopkosten	f	t	6
68	Distributiekosten	f	t	6
69	Algemene kosten	f	t	6
71	Rente baten	f	t	9
72	Rente- en overige financielelasten	f	t	9
73	Opbrengst overige activa	f	t	9
74	Incidentele baten en lasten	f	t	5
\.

