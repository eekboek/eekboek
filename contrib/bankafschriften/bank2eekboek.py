#!/usr/bin/python
# -*- coding: utf_8 -*-
#
# Bank2eekboek.py maakt van een bankrekeningoverzicht een Eekboek-mutaties-bestand.
# Op dit moment is bank2eekboek.py alleen geschikt voor:
# ING Bank NV (Postbank) Kommagescheiden (jjjjmmdd) csv-bestanden (v0.2)
#
# Het is de bedoeling hier in de toekomst formaten van andere banken aan toe te voegen.
# Neem even contact op met Jaap van Wingerde <bank2eekboek@vanwingerde.net>
# als uw bank nog niet ondersteund wordt.
#
# Bij dit script hoort een "bank2eekboek.csv.dat" bestand, waarin u koppelingen kunt aanbrengen tussen bijvoorbeeld
# nummer tegenrekening en grootboekrekening of debiteur. Een voorbeeld is bijgevoegd. Dit bestand is nu nog in 
# csv-formaat, in de toekomst maak ik dit misschien eenvoudiger.
#
# "bank2eekboek.csv.dat" ziet er bijvoorbeeld als volgt uit:
# "searchkey","searchvalue","writewhere","writewhat","ob"
# "Tegenrekening","266050522","Debiteur","GOOGLE",""
# "Tegenrekening","674352645","Grootboekrekening","260101","@H+"
#
# Discussie over het gebruik van bank2eekboek kan op de Eekboek-lijst
# <http://sourceforge.net/mailarchive/message.php?msg_name=18943.15693.159611.278451%40phoenix.squirrel.nl>
# plaatsvinden.
#
# Bank2eekboek is geschreven in Python Language <http://www.python.org/>.
#
# First published: 2009-05-03 (version: 0.2).
# This version: 0.3 (2009-05-06).
#
# Copyright: Jaap van Wingerde 2009 (All rights reserved)
#
# Author: Jaap van Wingerde,
# web: <http://yellowmatter.dyndns.org/accounting/eekboek/bank2eekboek/>,
# e-mail: <bank2eekboek@vanwingerde.net>,
# with a little help from the python-list
# <http://mail.python.org/pipermail/python-list/>.
#
# EekBoek is een electronisch boekhoudprogramma door Johan Vromans
# <http://www.vromans.org/johan/> bedoeld voor het midden- en kleinbedrijf
# <http://www.eekboek.nl/>, <http://sourceforge.net/mailarchive/forum.php?forum_name=eekboek-users>.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms the GNU General Public License as
# published by the Free Software Foundation <http://fsf.org/>.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# On Debian GNU/Linux systems, the complete text of both the GNU General Public
# License can be found below /usr/share/common-licenses/ .
#
import csv, re, codecs, glob, os, datetime
keys, number, Rekening , bankvalues, preg, file = "", 0, "", [], "", ""
def bankselection (csvfile):
    keys, dateformat, Rekening, preg = "", "", "", ""
    bankcsv = open (csvfile, "rb")
    lines = bankcsv.readlines()
    preg = "^\"Datum\",\"Naam / Omschrijving\",\"Rekening\",\"Tegenrekening\",\"Code\",\"Af Bij\",\"Bedrag \(EUR\)\",\"MutatieSoort\",\"Mededelingen"
    if re.search(preg, lines[0]) != None: 
        bank = "ing_postbank"
    line2 = lines[1]
    if (int(line2[1:5]) > 1950) and (int(line2[1:5]) < 2099):
        dateformat = "jjjjmmdd"
        try: datetime.date(int(line2[1:5]), int(line2[5:7]), int(line2[7:9]))
        except: dateformat = ""
    if bank == "ing_postbank" and dateformat == "jjjjmmdd":
        keys = ("Datum", "Naam", "Rekening", "Tegenrekening", "Code", "AfBij", "Bedrag", "MutatieSoort", "Mededelingen")
        split= re.split('\",\"', line2)
        Rekening = split[2]
    return keys, Rekening, preg
csvfiles = "%s/*.csv" % (os.getcwd())
csvs = glob.glob(csvfiles)
if len(csvs) == 0:
    print "\nEr staan geen csv-bestanden in <%s>. Dit script wordt beeindigd." % (os.getcwd())
    os._exit(1)
elif len(csvs) == 1:
    selection = bankselection(csvs[int(0)])
    if selection[0]  != "":
        print "\nEr staat één bruikbaar csv-bestand in <%s>: <%s>." % (os.getcwd(), csvs[int(0)])
        file = csvs[int(0)]
        number = 1
else: 
    print "\nDe volgende bruikbare csv-bestanden staan in directory <%s>:" % (os.getcwd())
    for csvfile in csvs:
        selection = bankselection(csvfile)
        if selection[0] != "":
            print "%s: <%s>" % (number, csvfile)
            number += 1
if number == 1:
    file = csvs[0]
elif number != 0:
    print "\nWelke csv-bestand wilt u omzetten in Eekboek-mutaties-formaat? 0 - %s" % (number-1)
    csvnumber = raw_input("Kies een nummer:   ")
    if int(csvnumber) < int(number):
        file = csvs[int(csvnumber)]
    else:
        print "Deze invoer is ongeldig. Het script wordt beëindigd."
        os._exit(1)
else:
    print "\nEr staan geen bruikbare csv-bestanden in <%s>. Dit script wordt beeindigd." % (os.getcwd())
    os._exit(1)
output = "%s.eb" % (file)
selection = bankselection(file)
keys = selection[0]
Rekening = selection[1]
ebfile = glob.glob(output)
if len(ebfile) == 1:
    print "\nHet bestand <%s> bestaat al.\n" % (output)
    overschrijven = raw_input("Wilt U het bestaande bestand overschrijven? j/n:   ")
    if overschrijven != "j":
        print "\nU wilt het bestaande bestand <%s> niet overschrijven. Dit script wordt beëindigd." % (output)
        os._exit(1)
    else:
        print "\nBestand <%s> wordt overschreven." % output
# Eerst het Eekboek-mutaties-bestand voorbereiden.
outfile = codecs.open(output, "wb", "utf_8")
outfile.write (Rekening)
outfile.write (":? YYYY-MM-DD \"Afschrift ? (YYYY)\"")
mutaties, gmutaties, dmutaties, datname = 0, 0, 0, "bank2eekboek.csv.dat", 
# Kijken of "bank2eekboek.csv.dat" bestaat
datname = "%s/bank2eekboek.csv.dat" % (os.getcwd())
datfile = glob.glob(datname)
if len(datfile) == 1:
    print "\nHet bestand <%s> bestaat en zal gebruikt worden." % (datname)
    dat = "True"
if len(datfile) == 0:
    print "\nHet bestand <%s> is niet aangetroffen. \"Grootboekrekening\" of \"Debiteur\" kunnen niet automagisch bepaald worden." % (datname)
    dat = "False"
# Bankrekening overzicht inlezen, eerste regel verwijderen en sorteren
bank = open (file, "rb")
lines = bank.readlines()
for line in lines:
    if re.search(selection[2], line) == None:
        bankvalues.append(line)
bankvalues.sort()
reader = csv.reader(bankvalues)
orikeys = reader.next()
for values in reader:
    record = {}
# Dictionary aanmaken met de door bankselection() geselecteerde keys en de values uit het bankrekeningoverzicht.
    record = dict(zip(keys,values))
# Datum formatteren (yyyy-mm-dd)
    date = record['Datum']
    Datum = "%s-%s-%s" % (date[0:4], date[4:6], date[6:8])
# Omschrijving formatteren. Ik haal alle relevante info uit het bankrekeningoverzicht
# en hou rekening met unicode.
    Omschrijving = u""
    Omschrijving = "\"%s %s, Tegenrekening: %s, %s ()\"" % (record['Naam'], record['Mededelingen'], record['Tegenrekening'], record['MutatieSoort'])
# Onzin uit de omschrijving halen
    Omschrijving = re.sub('Purpervlinder\s+14\s+3723\s+TZ', " " , Omschrijving)
    Omschrijving = re.sub('\s+', " " , Omschrijving)
    Omschrijving = Omschrijving.replace(" Tegenrekening: ,", "")
    Omschrijving = Omschrijving.replace(" ,", ",")
# Diacritische tekens toevoegen
    Omschrijving = Omschrijving.replace(u"priv?", u"privé")
    Omschrijving = Omschrijving.replace(u"Assuranti?n", u"Assurantiën")
    mutaties = mutaties + 1
    minus, ob, Debiteur, Grootboekrekening = "", "", "", "?"
# Bedrag formatteren.
    if record['AfBij'] == 'Af': minus = "-"
    Bedrag = "%s%s" % (minus, record['Bedrag'])
# "bank2eekboek.csv.dat" openen
    if dat != "False":
        key_search = open (datname, "rb")
        mut_reader = csv.reader(key_search)
        mut_keys = mut_reader.next()
        for mut_values in mut_reader:
            mut_record = {}
            mut_record = dict(zip(mut_keys,mut_values))
            if record[mut_record['searchkey']] ==  mut_record['searchvalue']:
                if mut_record['writewhere'] == "Debiteur":
                    Debiteur = mut_record['writewhat']
                    ob = mut_record['ob']
                    dmutaties = dmutaties + 1                    
                elif mut_record['writewhere'] == "Grootboekrekening":
                    Grootboekrekening = mut_record['writewhat']
                    ob = mut_record['ob']
                    gmutaties = gmutaties + 1
# Eekbeek-mutatie-bestand verder schrijven.
    if Debiteur == "":
        outfile.write (" \\\n")
        outfile.write ("std ")
        outfile.write (Datum)
        outfile.write (" ")
        outfile.write (Omschrijving)
        outfile.write (" ")
        outfile.write (Bedrag)
        outfile.write (ob)
        outfile.write (" ")
        outfile.write (Grootboekrekening)
    else:
        outfile.write (" \\\n")
        outfile.write ("crd ")
        outfile.write (Datum)
        outfile.write (" ")
        outfile.write (Debiteur)
        outfile.write (" ")
        outfile.write (Bedrag)
        outfile.write (ob)
outfile.close()
print "\nEekboek-mutatie-bestand <%s> is aangemaakt." % output
print "\nEr zijn %s mutaties geschreven." % (mutaties)
print "\nVan %s mutaties bleek het grootboeknummer bekend." % (gmutaties)
print "\nVan %s mutaties bleek de debiteur bekend." % (dmutaties)
bwmutaties = mutaties - gmutaties - dmutaties
print "\nU moet dus nog minimaal %s mutaties verder zelf aanpassen." % (bwmutaties)
os._exit(0)
