#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# This script add GO terms from an InterPro entry to another from a given list
# The file format should be: old_interpro_id,new_interpro_id per line (unix format)
#######################################################################################

import cx_Oracle
import ConfigParser
import re
import os
import sys
import time

configdata = ConfigParser.RawConfigParser()
configdata.read([os.path.expanduser('~/Desktop/genome3D/config/db.cfg'), '/nfs/msd/work2/typhaine/genome3D/config/db.cfg'])

#Connexion to interpro database
IPPROUSER=configdata.get('Global', 'ipproUser')
IPPROPASS=configdata.get('Global', 'ipproPass')
IPPROHOST=configdata.get('Global', 'ipproHost')

ipproconnection = cx_Oracle.connect(IPPROUSER+'/'+IPPROPASS+'@'+IPPROHOST)
ipprocursor = ipproconnection.cursor()
ipprocursor2 = ipproconnection.cursor()

#requests
search_go = "select GO_ID,source from interpro.interpro2go where entry_ac=:ipr"
search_existing_go = "select GO_ID from interpro.interpro2go where entry_ac=:ipr and go_id=:go_id and source=:source"
add_go = "insert into interpro.interpro2go values (:ipr,:go_id,:source)"

#get the file to read
file_name = sys.argv[1]
file_location = './'+file_name

my_file = open (file_location,'r')

for line in my_file:
    pattern_IPR1 = re.match("(IPR\d+),", line)
    pattern_IPR2 = re.search(",(IPR\d+)",line)
     
    entry = line.strip()
    
    #if two IPR (old and new)
    if pattern_IPR1 and pattern_IPR2:
        #get ipr only
        ipr1 = pattern_IPR1.group(1)
        ipr2 = pattern_IPR2.group(1)
        
        #search go terms from previous entry
        ipprocursor.execute(search_go,{'ipr':ipr1})
        get_go_ipr1_sth = ipprocursor.fetchall()
        
        #for each GO term found
        for go_term in get_go_ipr1_sth:
            exists_go=""
            print ipr1+" "+ipr2
            print go_term[0]

            #search if GO term already assigned to the new entry
            ipprocursor2.execute(search_existing_go,{'ipr':ipr2,'go_id':go_term[0],'source':go_term[1]})
            exists_go = ipprocursor2.fetchone()
            
            #if GO term not yet in new entry, add it
            if exists_go == None:
                ipprocursor2.execute(add_go,{'ipr':ipr2,'go_id':go_term[0],'source':go_term[1]})
                ipproconnection.commit()
                print go_term[0]+" inserted"
