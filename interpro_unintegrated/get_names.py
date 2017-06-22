#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# This script get GENE3D, SSF and ECOD names for InterPro entries
#######################################################################################

import cx_Oracle
import ConfigParser
import re
import os
import sys
from scipy.optimize._tstutils import description
import code

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

def getECODName(pdbecursor,gene3d):
    
    name = ""
    
    get_name = "select distinct x_name,h_name,t_name \
                from ecod_description_new ed \
                join node_mapping_ecod_new nm on REGEXP_SUBSTR(f_id, '\d+\.\d+')=nm.scop_dom \
                where cath_dom=:gene3d and nm.MUTUAL_EQUIVALENCE_MEDAL='a'"
     
    pdbecursor.execute(get_name, gene3d=gene3d)
    result = pdbecursor.fetchall()
 
    for row in result:
        if name != '':
            name = name+" ; "
        if row[0]:
            name = row[0]
        if row[1] :
            name = name +" / "+ row[1]
        else:
            name = name +" / "
        if row[2]:
            name = name + " / "+row[2]
            
    if name != '':
        name = name.replace(",", ";")
            
    return name


def getName(pdbecursor,code):
    #return the scop superfamily name or gene3d name for a given identifier
    
    scop = re.match("SSF(\d+)",code)
    gene3d = re.match("G3DSA:(\d+\.\d+\.\d+\.\d+)",code)
    name = ""
    get_name = ""

    if scop:
        code = scop.group(1)
        get_name = "select distinct(scop_superfamily) \
                        from sifts_admin_new.entity_scop \
                        join scop_class using (sunid) \
                        where superfamily_id = :code"
    elif gene3d:
        code = gene3d.group(1)
        get_name = "select distinct homol,cn.name \
                    from sifts_admin_new.cath_domain cd \
                    join cath_name cn using (cathcode) \
                    where CATHCODE=:code"
             
 
    pdbecursor.execute(get_name, code=code)
    result = pdbecursor.fetchall()
 
    for row in result:
        if scop and row[0]:
            name = row[0]
        
        if gene3d and row[1]:
            name = row[1]
        elif gene3d and (not row[1]) and row[0]:
            print row[0]
            name = "HOMOL: "+ row[0]
            
    if name != '':
        name = name.replace(",", ";")

    return name

#get the arguments
file_name = sys.argv[1]

#get the file
directoryToPrint = dirname +"/unintegrated/"
file_to_check = directoryToPrint+file_name
file_to_print = directoryToPrint+"ssf_gene3d_names_complete.csv"

os.system('rm  '+file_to_print)

#open the file to read
my_file = open (file_to_check,'r')
my_file_to_print = open (file_to_print,'w')



for line in my_file:
     #pattern matching CATH line
    pattern_gene3d = re.search("(G3DSA:(\d+\.\d+\.\d+\.\d+))",line)
    #pattern matching SCOP line
    pattern_ssf = re.search("(SSF\d+)",line)
    
    name_gene3d = ''
    name_ssf = ''
    name_ecod = ''

    line = line.strip()
#     print line
#     my_file_to_print.write(line+",")
    
    #search GENE3D and superfamily names
    if pattern_gene3d:
        name_gene3d = getName(pdbecursor,pattern_gene3d.group(1))
        name_ecod = getECODName(pdbecursor, pattern_gene3d.group(2))

    if pattern_ssf:
        name_ssf = getName(pdbecursor,pattern_ssf.group(1))
        
    
    #print names in the new file
#     if name_gene3d != '':
#         my_file_to_print.write(name_gene3d+",")
#     else:
#         my_file_to_print.write(",")
#            
#     if name_ssf != '':
#         my_file_to_print.write(name_ssf+",")
#     else:
#         my_file_to_print.write(",")
#        
#     if name_ecod != '':
#         my_file_to_print.write(name_ecod)
#        
#     my_file_to_print.write("\n")
    
