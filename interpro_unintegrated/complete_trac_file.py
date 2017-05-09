#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# For each cluster, this script get particular blocks (gold, one to many domains between cath and scop MDA blocks)
#######################################################################################

import urllib2
import os

import cx_Oracle
import ConfigParser
import sys
import re
import search_unintegrated

dirname = os.path.dirname(__file__)
if not dirname:
    dirname = '.'

config = ConfigParser.RawConfigParser()
configdata.read([os.path.expanduser('~/Desktop/genome3D/config/db.cfg'), '/nfs/msd/work2/typhaine/genome3D/config/db.cfg'])

#Connexion to interpro database
IPPROUSER=config.get('Global', 'ipproUser')
IPPROPASS=config.get('Global', 'ipproPass')
IPPROHOST=config.get('Global', 'ipproHost')

ipproconnection = cx_Oracle.connect(IPPROUSER+'/'+IPPROPASS+'@'+IPPROHOST)
ipprocursor = ipproconnection.cursor()

directoryToPrint = dirname + '/'
unintegrated_gold_blocks_file = directoryToPrint+"gold_for_trac"
unintegrated_trac = directoryToPrint+"gold_for_trac_complete"

begin_file = open(unintegrated_gold_blocks_file, 'r')
new_file = open(unintegrated_trac,'w')

#get InterPro identifiers
getIPR = " select\
	    e.entry_ac\
	    from interpro.method m\
	    left outer join interpro.mv_method_match@iprel was on (m.method_ac= was.method_ac)\
	    left outer join interpro.entry2method em on (m.method_ac=em.method_ac)\
	    left outer join interpro.entry e on (e.entry_ac=em.entry_ac)\
	    where m.dbcode like :dbcode and 1=1 and 1=1 and 1=1 and m.method_ac=:method\
	    group by e.entry_ac"


for row in begin_file:
	pattern = re.search(r"(G3DSA:(\d+\.\d+\.\d+\.\d+))",row)

	if pattern:
		cluster_node = pattern.group(2)
		new_file.write("|-----------------------------------------------------------\n")
		new_file.write("{{{#!th rowspan=2\n")
		new_file.write("[cluster:"+cluster_node+" "+cluster_node+"]\n")
		new_file.write("}}}\n")

	pattern_integrate = re.search(r"UNINTEGRATED",row)
	row = row.strip('\n')
	first_line = re.search(r"cluster",row)
	pattern_SSF = re.search(r"(SSF\d+)",row)

	if not pattern_integrate and not first_line:
		
		columns = row.split(' || ')
		to_search = ''
		db_type = ''
		ipr = ''

		#determine method and db type to search
		if pattern_SSF:
			to_search = pattern_SSF.group(1)
			db_type = 'Y'
		else:
			to_search = pattern.group(1)
			db_type = 'X'

		#search interpro identifier
		ipprocursor.execute(getIPR,(db_type,to_search)) or die
		get_IPR_sth = ipprocursor.fetchall()

		for row_ippro in get_IPR_sth:
			ipr = row_ippro[0]

		#print data in the new file
		for data in range(len(columns)):
			if data != 3 and data !=4:
				new_file.write(columns[data])
			#add IPR
			elif data == 3:
				new_file.write(str(ipr))
			#add none in integration date column
			elif data == 4:
				new_file.write("none")

			#if not last data
			if data < len(columns)-1:
				new_file.write(" || ")
			else:
				new_file.write(" ||\n")
	else:
		new_file.write(row)
		new_file.write(' ||\n')

begin_file.close()
new_file.close()
