#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# This script get gold block information from PDBe database for integrated GENE3D and SSF in InterPro
#######################################################################################

import cx_Oracle
import ConfigParser
import re
import os
import sys
from django.template.context_processors import request

dirname = os.path.dirname(__file__)
if not dirname:
    dirname = '.'

#databases connection

configdata = ConfigParser.RawConfigParser()
configdata.read([os.path.expanduser('~/Desktop/genome3D/config/db.cfg'), '/nfs/msd/work2/typhaine/genome3D/config/db.cfg'])

#Connexion to PDBE_TEST database
PDBEUSER=configdata.get('Global', 'pdbeUser')
PDBEPASS=configdata.get('Global', 'pdbePass')
PDBEHOST=configdata.get('Global', 'pdbeHost')

pdbeconnection = cx_Oracle.connect(PDBEUSER+'/'+PDBEPASS+'@'+PDBEHOST)
pdbecursor = pdbeconnection.cursor()

#Connexion to interpro database
IPPROUSER=configdata.get('Global', 'ipproUser')
IPPROPASS=configdata.get('Global', 'ipproPass')
IPPROHOST=configdata.get('Global', 'ipproHost')

ipproconnection = cx_Oracle.connect(IPPROUSER+'/'+IPPROPASS+'@'+IPPROHOST)
ipprocursor = ipproconnection.cursor()


def get_gold (pdbecursor,entry,type):
    # search if entry is in a gold block or not
    
    #get corresponding sccs code for SSF
    if type == 'SSF':
        entry = getSSF(pdbecursor,entry)
        
#     entry = '%'+entry+'%'
    
#     request = "select gold from cluster_block_new where block like :entry "
    request = "select MUTUAL_EQUIVALENCE_MEDAL from node_mapping_new where cath_dom=:entry or scop_dom=:entry"
    pdbecursor.execute(request, {'entry':entry})
    request_sth = pdbecursor.fetchall()
    
    for row in request_sth:
        if row[0]:
            gold = row[0]
            
#             if gold == 'yes':
            if gold == 'a':
                return 'yes'

    return 'no'
    
    

def getSSF(pdbecursor,scop):
    #return the scop superfamily id corresponding to the SCCS
    request = "select distinct sccs from sifts_admin_new.SCOP_CLASS where superfamily_id=:scop"
    pdbecursor.execute(request,{'scop':scop})
    request_sth = pdbecursor.fetchall()

    for row in request_sth:
        sccs = row[0]
        
        m = re.match ("(.\.\d+\.\d+)\.",sccs)
        if m:
            sccs = m.group(1)
        return sccs

    return 0

def getNbSignatures(ipprocursor,ipr):
    #get the number of signatures in the current entry
    
    get_number_signatures = "select m.method_ac\
        from interpro.method m\
        left outer join interpro.mv_method_match@iprel was on (m.method_ac= was.method_ac)\
        left outer join interpro.entry2method em on (m.method_ac=em.method_ac)\
        left outer join interpro.entry e on (e.entry_ac=em.entry_ac)\
        where e.entry_ac=:ipr"
    
    ipprocursor.execute(get_number_signatures,{'ipr':ipr})
    request_sth = ipprocursor.fetchall()
    
    for row in request_sth:
        method = row[0]
        if not re.search("G3DSA",method) and not re.search("SSF",method) :
            return 'false'
    
    return 'true'
    
#get the arguments
file_name = sys.argv[1]

#get the file
directoryToPrint = dirname +"/unintegrated/"
file_to_check = directoryToPrint+file_name
file_to_print = directoryToPrint+"ssf_gene3d_entries_complete.csv"

#delete existing file
os.system('rm '+file_to_print)

#open the file to read
my_file = open (file_to_check,'r')
my_file_to_print = open (file_to_print,'w')



for line in my_file:
     #pattern matching CATH line
    pattern_cath = re.search("G3DSA:(\d+\.\d+\.\d+\.\d+)",line)
    #pattern matching SCOP line
    pattern_scop = re.search("SSF(\d+)",line)
    #get IPR
    pattern_ipr = re.search("(IPR\d+)",line)
    
    gold = ''
    line = line.strip()
    alone = ''
    
    #search if gold block
    if pattern_cath:
        gold = get_gold(pdbecursor,pattern_cath.group(1),'GENE3D')
    if pattern_scop:
        gold = get_gold(pdbecursor,pattern_scop.group(1),'SSF')
    
    #search if alone in InterPro entry
    if pattern_ipr:
        alone = getNbSignatures(ipprocursor, pattern_ipr.group(1))
    
#     print line+","+gold+","+alone
    my_file_to_print.write(line+","+gold+","+alone+"\n")
        



