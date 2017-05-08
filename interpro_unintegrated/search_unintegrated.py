#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# This script get all the SCOP and CATH entries that are not integrated into InterPro signatures
#######################################################################################

import re
import comparepfam
from scipy.optimize._tstutils import description

def getUnintegrated(pdbecursor,ipprocursor,nodes,unintegrated_file,value):

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
	interpro_nodes=[]

	toReturn=[]

	for node in nodes:
		if re.match("^[a-z]",node):
			#search corresponding SSF signature
			scopSSF = getSSF(pdbecursor,node)
			scop_search = "SSF"+str(scopSSF)
			interpro_nodes.append(scop_search)

			ipprocursor.execute(get_unintegrated,('Y',scop_search)) or die
			get_unintegrated_sth = ipprocursor.fetchall()

			if toPrintScop != '':
				toPrintScop+="\n"

			toPrintScop+="|| "

			for row_ippro in get_unintegrated_sth:
				nbprot = ''
				#get the number of protein corresponding to this signature
				ipprocursor.execute(get_nb_protein,search=scop_search)
				get_nb_protein_sth = ipprocursor.fetchall()

				for row_prot in get_nb_protein_sth:
					#if protein found => print the number
					if row_prot[0]:
						nbprot = str(row_prot[0])

				#if found signature but no corresponding InterPro identifier => unintegrated
				if not row_ippro[0]:
					toPrintScop+= "UNINTEGRATED: "+scop_search+" || "+nbprot+" || || || || || ||" 
					unintegrated_scop+=1
				else:
					toPrintScop+= scop_search+" || "+nbprot+" || || || "+row_ippro[0]+" || none || ||"
		
		elif re.match("^\d+\.\d+$",node):
			#search ECOD equivalence
			interpro_nodes.append(node)
			
			table_description = getDescriptionECOD(pdbecursor, node)
			description = ''
			if len(table_description) != 0:
				cpt = 0
				for desc in table_description:
					if cpt < len(table_description)-1:
						description+=desc+"[[BR]]"
					else:
						description+=desc
					cpt+=1
			
			if toPrintScop != '':
				toPrintScop+="\n"

			toPrintScop+="|| ECOD: "+node+" || || "+description+" || || || || ||" 
			
		else:
			#search corresponding GENE3D signature
			if cluster_node == '':
				cluster_node=node

			cath_search = "G3DSA:"+str(node)
			interpro_nodes.append(cath_search)

			ipprocursor.execute(get_unintegrated,('X',cath_search)) or die
			get_unintegrated_sth = ipprocursor.fetchall()

			if toPrintCath != '':
				toPrintCath+="\n"

			toPrintCath+="|| "

			for row_ippro in get_unintegrated_sth:
				nbprot = ''
				#get the number of protein corresponding to this signature
				ipprocursor.execute(get_nb_protein,search=cath_search)
				get_nb_protein_sth = ipprocursor.fetchall()

				for row_prot in get_nb_protein_sth:
					#if protein found => print the number
					if row_prot[0]:
						nbprot= str(row_prot[0])

				#if found signature but no corresponding InterPro identifier => unintegrated
				if not row_ippro[0]:
					toPrintCath+= "UNINTEGRATED: "+cath_search+" || "+nbprot+" || || || || || ||"
					unintegrated_cath+=1
				else:
					toPrintCath+= cath_search+" || "+nbprot+" || || || "+row_ippro[0]+" || none || ||"
		
	#determine if unintegrated pair
	total = unintegrated_cath + unintegrated_scop

	if total == len(nodes):
		unintegrated_pair+=1

	#print in file
	if unintegrated_cath != 0 or unintegrated_scop != 0:
# 		comparepfam.comparePositions(ipprocursor,interpro_nodes)
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


def getDescriptionECOD(pdbecursor,ecod):
	#search description for homology and topology levels ECOD description table
	get_ecod_description = "select distinct h_name,t_name from ecod_description_test where f_id like '"+ecod+"%'"

	pdbecursor.execute(get_ecod_description)
	request = pdbecursor.fetchall()
	
	table_description=list()
	
	for all_row in request:
		if all_row[0] and all_row[1] : #Homology and Topology description found
			description = "H: "+all_row[0]+", T: "+all_row[1]
		elif  all_row[1] : #Only Topology description found
			description = "T: "+all_row[1]
		elif all_row[0] : #Only Homology description found
			description = "H: "+all_row[0]	
		else: #No description found
			description = ''
			
		if description != '':
			table_description.append(description)
	
	return table_description


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
