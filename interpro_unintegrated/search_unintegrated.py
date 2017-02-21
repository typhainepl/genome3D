#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# This script get all the SCOP and CATH entries that are not integrated into InterPro signatures
#######################################################################################

import re

def getUnintegrated(pdbecursor,ipprocursor,nodes,unintegrated_file):


	file = open(unintegrated_file,'a')

	#get the superfamilies not integrated in InterPro
	get_unintegrated=" select\
	    e.entry_ac\
	    from interpro.method m\
	    left outer join interpro.mv_method_match@iprel was on (m.method_ac= was.method_ac)\
	    left outer join interpro.entry2method em on (m.method_ac=em.method_ac)\
	    left outer join interpro.entry e on (e.entry_ac=em.entry_ac)\
	    where m.dbcode like :dbcode and 1=1 and 1=1 and 1=1 and m.method_ac=:method\
	    group by e.entry_ac"


	get_nb_protein = "select ct_prot from interpro_analysis.feature_summary where feature_id=:search"
	
	cluster_node=''
	toPrintCath=''
	toPrintScop=''
	unintegrated_cath=0
	unintegrated_scop=0
	unintegrated_pair=0
	notInDb_cath=0
	notInDb_scop=0

	toReturn=[]

	for value in nodes:
		if re.match("^[a-z]",value):
			#search corresponding SSF signature
			scopSSF = getSSF(pdbecursor,value)
			scop_search = "SSF"+str(scopSSF)

			ipprocursor.execute(get_unintegrated,('Y',scop_search)) or die
			get_unintegrated_sth = ipprocursor.fetchall()

			if toPrintScop != '':
				toPrintScop+="\n"

			toPrintScop+="|| "+scop_search+" || "

			for row_ippro in get_unintegrated_sth:

				#get the number of protein corresponding to this signature
				ipprocursor.execute(get_nb_protein,search=scop_search)
				get_nb_protein_sth = ipprocursor.fetchall()

				for row_prot in get_nb_protein_sth:
					#if protein found => print the number
					if row_prot[0]:
						toPrintScop+= str(row_prot[0]) + " || "

				#if found signature but no corresponding InterPro identifier => unintegrated
				if not row_ippro[0]:
					toPrintScop+= "|| || ||"
					unintegrated_scop+=1
				else:
					toPrintScop+= row_ippro[0]+" || none || ||"

		else:
			#search corresponding GENE3D signature
			if cluster_node == '':
				cluster_node=value

			cath_search = "G3DSA:"+str(value)

			ipprocursor.execute(get_unintegrated,('X',cath_search)) or die
			get_unintegrated_sth = ipprocursor.fetchall()

			if toPrintCath != '':
				toPrintCath+="\n"

			toPrintCath+="|| "+cath_search+" || "

			for row_ippro in get_unintegrated_sth:
				
				#get the number of protein corresponding to this signature
				ipprocursor.execute(get_nb_protein,search=cath_search)
				get_nb_protein_sth = ipprocursor.fetchall()

				for row_prot in get_nb_protein_sth:
					#if protein found => print the number
					if row_prot[0]:
						toPrintCath+= str(row_prot[0]) + " || "

				#if found signature but no corresponding InterPro identifier => unintegrated
				if not row_ippro[0]:
					toPrintCath+= "|| || ||"
					unintegrated_cath+=1
				else:
					toPrintCath+= row_ippro[0]+" || none || ||"
		
	#determine if unintegrated pair
	total = unintegrated_cath + unintegrated_scop

	if total == len(nodes):
		unintegrated_pair+=1

	#print in file
	if unintegrated_cath != 0 or unintegrated_scop != 0:
		file.write("|-----------------------------------------------------------\n")
		file.write("{{{#!th rowspan="+str(len(nodes))+"\n")
		file.write("[cluster:"+str(cluster_node)+" "+str(cluster_node)+"]\n")
		file.write("}}}\n")
		file.write(toPrintCath+"\n")
		file.write(toPrintScop+"\n")

	toReturn.append(unintegrated_cath)
	toReturn.append(unintegrated_scop)
	toReturn.append(notInDb_cath)
	toReturn.append(notInDb_scop)
	toReturn.append(unintegrated_pair)

	file.close()

	return toReturn


def getBeginEnd(ipprocursor, search):

	ipprocursor.prepare("select pos_from, pos_to from match where method_ac=:method_ac")

	begin = 0
	end   = 0
	cpt	  = 0

	ipprocursor.execute(None,search)
	search_begin_end_dbh = ipprocursor.fetchall()

	for row in search_begin_end_dbh:
		begin_temp = row[2]
		end_temp   = row[3]

		if cpt == 0:
			begin = begin_temp
			end   = end_temp
		else:
			if begin_temp < begin and begin_temp < end:
				begin = begin_temp

			if end_temp > end and end_temp > begin:
				end = end_temp


def getSSF(pdbecursor,scop):
	#return the scop superfamily id corresponding to the SCCS

	pdbecursor.execute("select distinct superfamily_id,sccs from SCOP_CLASS")
	request = pdbecursor.fetchall()

	for all_row in request:
		sccs = all_row[1]
		superfamily = all_row[0]

		m = re.match ("(.\.\d+\.\d+)\.",sccs)
		if m:
			sccs = m.group(1)
		
		if sccs == scop:
			return superfamily

return 0