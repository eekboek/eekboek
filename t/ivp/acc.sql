-- Grootboekrekeningen

COPY Accounts (acc_id, acc_desc, acc_struct, acc_balres, acc_debcrd, acc_kstomz, acc_btw, acc_ibalance, acc_balance) FROM stdin;
110	Aanloopkosten	11	t	t	t	0	0	0
111	Afschrijving aanloopkst.	11	t	f	t	0	0	0
200	Gebouwen en terreinen	12	t	t	t	0	0	0
201	Afschrijving gebouwen	12	t	f	t	0	0	0
210	Verbouwing	12	t	t	t	0	0	0
211	Afschrijving verbouwingen	12	t	f	t	0	0	0
220	Machines en installaties	12	t	t	t	0	0	0
221	Afschrijving mach. & installaties	12	t	f	t	0	0	0
230	Inventaris en inrichting	12	t	t	t	1	0	0
231	Afschrijving inventaris & inrichting	12	t	f	t	0	0	0
240	Computers	12	t	t	t	1	0	0
241	Afschrijving computers	12	t	f	t	0	0	0
320	Lening u/g de heer A	13	t	t	t	0	0	0
500	Kapitaal	31	t	f	t	0	0	0
510	Privé stortingen	31	t	f	t	0	0	0
520	Privé opnamen	31	t	f	t	0	0	0
530	Privé rente	31	t	f	t	0	0	0
540	Privé ziektekosten	31	t	f	t	0	0	0
550	Privé belastingen	31	t	f	t	0	0	0
560	Privé schenkingen	31	t	f	t	0	0	0
570	Privé verzekeringen	31	t	f	t	0	0	0
580	Privé buitengewone lasten	31	t	f	t	0	0	0
590	Privé uitgaven overige	31	t	f	t	0	0	0
810	Lening Bank	41	t	f	t	0	0	0
811	Middellang krediet Bank	41	t	f	t	0	0	0
880	Lening opgenomen	44	t	f	t	0	0	0
890	Overige leningen	44	t	f	t	0	0	0
900	Aandelen	23	t	t	t	0	0	0
910	Obligaties	23	t	t	t	0	0	0
1000	Kas	24	t	t	t	0	0	0
1120	Postbank	24	t	t	t	0	0	0
1150	Deposito	24	t	t	t	0	0	0
1190	Kruisposten	24	t	t	t	0	0	0
1191	Kruisposten Kas	24	t	t	t	0	0	0
1192	Kruisposten overboekingen	24	t	t	t	0	0	0
1200	Debiteuren	22	t	t	t	0	0	0
1210	Factoring debiteuren	22	t	f	t	0	0	0
1220	Debiteuren vorig boekjaar	22	t	t	t	0	0	0
1250	Dubieuze debiteuren	22	t	t	t	0	0	0
1290	Voorziening debiteuren	22	t	t	t	0	0	0
1300	Waarborgsommen	22	t	t	t	0	0	0
1350	Te factureren omzet	22	t	t	t	0	0	0
1360	Te ontvangen rente	22	t	t	t	0	0	0
1370	Te ontvangen ziekengeld	22	t	t	t	0	0	0
1380	Te ontvangen provisie	22	t	t	t	0	0	0
1400	Vooruitbet. huisvestingskosten	22	t	t	t	0	0	0
1410	Vooruitbet. reclamekosten	22	t	t	t	0	0	0
1420	Vooruitbet. verzekering	22	t	t	t	0	0	0
1430	Vooruitbet. autokosten	22	t	t	t	0	0	0
1440	Vooruitbet. kantoorartikelen	22	t	f	t	0	0	0
1500	BTW Verkoop Hoog	48	t	f	t	0	0	0
1510	BTW Verkoop Laag	48	t	f	t	0	0	0
1520	BTW Inkoop Hoog	48	t	t	t	0	0	0
1530	BTW Inkoop Laag	48	t	t	t	0	0	0
1540	BTW autokostenverg. 12%	48	t	f	t	0	0	0
1550	BTW Import	48	t	f	t	0	0	0
1560	Omzetbelasting betaald	48	t	f	t	0	0	0
1600	Crediteuren	46	t	f	t	0	0	0
1620	Crediteuren vorig boekjaa	46	t	f	t	0	0	0
1650	Nog te ontvangen fakturen	46	t	f	t	0	0	0
1710	Loonheffing betaald	48	t	f	t	0	0	0
1711	Ingehouden loonheffing	48	t	f	t	0	0	0
1720	Bedrijfsvereniging bet.	48	t	f	t	0	0	0
1721	Berekende premie BVG	48	t	f	t	0	0	0
1730	Pensioenpremie betaald	48	t	f	t	0	0	0
1731	Berekende pesioenpremie	48	t	f	t	0	0	0
1740	VUT premie betaald	48	t	f	t	0	0	0
1741	Berekende VUT premie	48	t	f	t	0	0	0
1750	Sociaal fonds betaald	48	t	f	t	0	0	0
1751	Berekende premie S. Fonds	48	t	f	t	0	0	0
1900	Aflossingsverplichtingen	49	t	f	t	0	0	0
1910	Reservering vakantiegeld	49	t	f	t	0	0	0
1911	Reservering vakantiedagen	49	t	f	t	0	0	0
1920	Te betalen accountantskosten	49	t	f	t	0	0	0
1921	Te betalen advieskosten	49	t	f	t	0	0	0
1922	Te betalen autokosten	49	t	f	t	0	0	0
1923	Te betalen algemene kosten	49	t	f	t	0	0	0
1924	Te betalen personeelskosten	49	t	f	t	0	0	0
1925	Te betalen rente	49	t	f	t	0	0	0
1926	Te betalen huisvestingskosten	49	t	f	t	0	0	0
1929	Te betalen overige kosten	49	t	f	t	0	0	0
1950	Netto lonen en salarissen	49	t	f	t	0	0	0
1960	Pensioen verzekeringsmij.	49	t	f	t	0	0	0
1990	Diverse schulden kort	49	t	f	t	0	0	0
2000	Vraagposten	25	t	f	t	0	0	0
2200	Kostenspreiding vorderingen	25	t	t	t	0	0	0
2210	Kostenspreiding schulden	25	t	f	t	0	0	0
2400	Onbekende betalingen	25	t	f	t	0	0	0
2900	Correctierekening	25	t	t	t	0	0	0
3000	Voorraad	21	t	t	t	0	0	0
3900	Voorziening incourante voorraad	21	t	f	t	0	0	0
4000	Bruto lonen	60	f	t	t	0	0	0
4001	Tantième	60	f	t	t	0	0	0
4002	Gratificaties	60	f	t	t	0	0	0
4010	Overhevelingstoeslag	60	f	t	t	0	0	0
4020	Premiespaarregeling	60	f	t	t	0	0	0
4021	Loonheffing spaarregeling	60	f	t	t	0	0	0
4070	Mutatie vakantiegeld	60	f	t	t	0	0	0
4071	Mutatie vakantiedagen	60	f	t	t	0	0	0
4080	Ontvangen ziekengeld	60	f	t	t	0	0	0
4090	Doorberekende salarissen	60	f	t	t	0	0	0
4100	Bedrijfsvereniging  premies	61	f	t	t	0	0	0
4101	Ingehouden pr. bedr. vereniging	61	f	t	t	0	0	0
4110	VUT premie	61	f	t	t	0	0	0
4111	Ingehouden VUT premie	61	f	t	t	0	0	0
4120	Sociaal fonds	61	f	t	t	0	0	0
4121	Ingehouden sociaal fonds	61	f	t	t	0	0	0
4130	Pensioenpremie	61	f	t	t	0	0	0
4131	Ingehouden pensioenpremies	61	f	t	t	0	0	0
4140	Ziekteverzuimverzekering	61	f	t	t	0	0	0
4150	Ziektekostenverzekering	61	f	t	t	0	0	0
4151	Bijdrage ziektekostenverzekering	61	f	t	t	0	0	0
4170	Soc. lasten vakantiegeld	61	f	t	t	0	0	0
4171	Soc. lasten vakantiedagen	61	f	t	t	0	0	0
4180	Soc. lasten ontv. ziekengeld	61	f	t	t	0	0	0
4190	Doorberekende soc. lasten	61	f	t	t	0	0	0
4200	Reiskostenvergoedingen	62	f	t	t	0	0	0
4205	Consultancy ingekocht	62	f	t	t	0	0	0
4210	Vaste reiskostenverg.	62	f	t	t	0	0	0
4220	Vrijgestelde vergoedingen	62	f	t	t	0	0	0
4230	Studiekosten	62	f	t	t	0	0	0
4240	Kostenvergoeding	62	f	t	t	0	0	0
4250	Representatie vergoeding	62	f	t	t	0	0	0
4260	Uitzendburo	62	f	t	t	1	0	0
4270	Kantine en consumptie	62	f	t	t	0	0	0
4280	Bedrijfskleding personeel	62	f	t	t	1	0	0
4290	Overige personeelskosten	62	f	t	t	0	0	0
4300	Afschr. kosten gebouwen	63	f	t	t	0	0	0
4310	Afschr. kosten verbouwing	63	f	t	t	0	0	0
4320	Afschr. kosten mach & ins	63	f	t	t	0	0	0
4330	Afschr. kosten inv. & inr	63	f	t	t	0	0	0
4340	Afschr. kosten computers	63	f	t	t	0	0	0
4350	Afschr. kosten auto's	63	f	t	t	0	0	0
4360	Res verkoop mat vaste act	63	f	f	t	0	0	0
4380	Afschr. kosten goodwill	64	f	t	t	0	0	0
4390	Afschr. kosten aanloopkosten	64	f	t	t	0	0	0
4500	Huur bedrijfspand	65	f	t	t	1	0	0
4510	Servicekosten	65	f	t	t	1	0	0
4520	Gas  water & electra	65	f	t	t	0	0	0
4530	Vaste lasten	65	f	t	t	0	0	0
4540	Onderhoud bedrijfspand	65	f	t	t	1	0	0
4550	Schoonmaakkosten	65	f	t	t	1	0	0
4560	Verzekering bedrijfspand	65	f	t	t	0	0	0
4590	Overige huisvestingskosten	65	f	t	t	1	0	0
4600	Leasekosten auto	66	f	t	t	1	0	0
4610	Brandstof auto	66	f	t	t	1	0	0
4620	Onderhoud auto	66	f	t	t	1	0	0
4630	Verzekering auto	66	f	t	t	0	0	0
4640	Kilometervergoedingen	66	f	t	t	0	0	0
4650	Huur auto	66	f	t	t	1	0	0
4670	Boetes	66	f	t	t	0	0	0
4671	Boetes 0% aftrekbaar	66	f	t	t	0	0	0
4680	BTW privégebruik auto	66	f	t	t	0	0	0
4690	Overige autokosten	66	f	t	t	1	0	0
4700	Reclamekosten	67	f	t	t	1	0	0
4710	Advertentiekosten	67	f	t	t	1	0	0
4711	Sponsoring	67	f	t	t	0	0	0
4720	Beurskosten	67	f	t	t	1	0	0
4730	Relatiegeschenken	67	f	t	t	0	0	0
4740	Reis- en verblijfkosten	67	f	t	t	1	0	0
4741	Reis- en verblijfk. 90%	67	f	t	t	1	0	0
4742	Voedsel en drank 90%	67	f	t	t	0	0	0
4750	Representatiekosten	67	f	t	t	1	0	0
4751	Representatiekosten 90%	67	f	t	t	0	0	0
4760	Credit-cardkosten	67	f	t	t	0	0	0
4770	Factoringkosten	67	f	t	t	0	0	0
4780	Kasverschillen	69	f	t	t	0	0	0
4790	Overige verkoopkosten	67	f	t	t	1	0	0
4800	Verzending portikosten	69	f	t	t	0	0	0
4810	Vervoerskosten	68	f	t	t	1	0	0
4890	Overige distributiekosten	68	f	t	t	1	0	0
4900	Telefoon- en faxkosten	69	f	t	t	1	0	0
4905	Internetkosten	69	f	t	t	1	0	0
4910	Contributies & abonnementen	69	f	t	t	0	0	0
4920	Verzekering algemeen	69	f	t	t	0	0	0
4930	Kantoorartikelen	69	f	t	t	1	0	0
4931	Computerbenodigdheden	69	f	t	t	1	0	0
4932	Vakliteratuur	69	f	t	t	3	0	0
4940	Accountantskosten	69	f	t	t	1	0	0
4941	Administratiekosten	69	f	t	t	1	0	0
4942	Loonadministratiekosten	69	f	t	t	1	0	0
4943	Notaris & advocaatkosten	69	f	t	t	1	0	0
4950	Drukwerk & papier	69	f	t	t	1	0	0
4960	Branche-organisatiekosten	69	f	t	t	0	0	0
4970	Postzegels	69	f	t	t	0	0	0
4980	Bankkosten	69	f	t	t	0	0	0
4990	Overige algemene kosten	69	f	t	t	1	0	0
4991	Bijzondere baten & lasten	69	f	t	t	0	0	0
7000	Inkoop materiaal	52	f	f	t	1	0	0
7800	Mutatie eindvoorraad	52	f	t	t	0	0	0
7900	Betalingskorting inkoop	52	f	f	t	0	0	0
7920	Prijsverschillen inkoop	52	f	f	t	0	0	0
8000	Omzet advisering BTW hoog	51	f	f	f	1	0	0
8010	Omzet advisering BTW vrij	51	f	f	f	0	0	0
8100	Omzet royalties	51	f	f	f	0	0	0
8200	Omzet editing	51	f	f	f	1	0	0
8300	Omzet cursussen	51	f	f	f	1	0	0
8310	Omzet cursuslicenties	51	f	f	f	1	0	0
8400	Omzet boeken	51	f	f	f	3	0	0
8600	Omzet diversen BTW hoog	51	f	f	f	1	0	0
8610	Omzet diversen BTW laag	51	f	f	f	3	0	0
8620	Omzet diversen BTW vrij	51	f	f	f	0	0	0
8680	Omzet naar kosten BTW hoo	53	f	f	f	1	0	0
8690	Doorbelaste omzet naar kosten	53	f	t	t	0	0	0
8700	Kleine ondernemersregeling	53	f	f	t	0	0	0
8800	Huuropbrengst	53	f	f	t	0	0	0
8900	Betalingskorting verkoop	51	f	f	t	0	0	0
8910	Korting  verkoop	51	f	f	t	0	0	0
8920	Prijsverschillen verkoop	51	f	f	t	0	0	0
9000	Rente bate deposito	71	f	f	t	0	0	0
9040	Rente bate lening u/g	71	f	f	t	0	0	0
9052	Rente bate Postbank	71	f	f	t	0	0	0
9080	Rente bate belastingen	71	f	f	t	0	0	0
9090	Rente bate overige	71	f	f	t	0	0	0
9100	Rente last hypotheek pand	72	f	t	t	0	0	0
9110	Rente last lening bank	72	f	t	t	0	0	0
9111	Rente last m.lang krediet	72	f	t	t	0	0	0
9120	Rente last fin. lease auto	72	f	t	t	0	0	0
9140	Rente last lening o/g	72	f	f	t	0	0	0
9152	Rente last Postbank	72	f	f	t	0	0	0
9170	Rente last factormaatschappij	72	f	t	t	0	0	0
9180	Rente last belastingen	72	f	t	t	0	0	0
9190	Rente last overige	72	f	t	t	0	0	0
9200	Opbrengst effecten	73	f	f	t	0	0	0
9210	Mutatie effecten	73	f	f	t	0	0	0
9300	Winst verkoop boeken	74	f	f	t	3	0	0
\.

