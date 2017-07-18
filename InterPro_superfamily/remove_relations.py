#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# This script removes relations (parent/child, contains/found in) for InterPro entries from a given list
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

#requests
delete_entry2entry_parent = "delete from interpro.entry2entry where parent_ac=:entry"
delete_entry2entry_child = "delete from interpro.entry2entry where entry_ac=:entry"
delete_entry2comp_contains = "delete from interpro.entry2comp where entry1_ac=:entry"
delete_entry2comp_contains_by = "delete from interpro.entry2comp where entry2_ac=:entry"

#get the file to read
file_name = sys.argv[1]
file_location = './'+file_name

my_file = open (file_location,'r')

for line in my_file:
    pattern_entry = re.search("IPR",line)
     
    entry = line.strip()
     
    if pattern_entry:
        #delete entries where entry is a parent
        ipprocursor.execute(delete_entry2entry_parent,entry=entry)
        
        #delete entries where entry is a child
        ipprocursor.execute(delete_entry2entry_child,entry=entry)

        #delete entries where entry is a container
        ipprocursor.execute(delete_entry2comp_contains,entry=entry)

        #delete entries where entry found in
        ipprocursor.execute(delete_entry2comp_contains_by,entry=entry)
        
        #commit changes
        ipproconnection.commit()

        
        
        
        
        
        
        
        