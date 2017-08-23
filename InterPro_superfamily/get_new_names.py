#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# This script get the name of an InterPro entry from a given list
# The file format is one InterPro id per line (unix format)
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
search_name = "select name from interpro.entry where entry_ac=:ipr"

#get the file to read
file_name = sys.argv[1]
file_location = './'+file_name

my_file = open (file_location,'r')

for line in my_file:
    pattern_IPR = re.search("(IPR\d+)", line)
    
    if pattern_IPR:
        ipr = pattern_IPR.group(1)
        ipprocursor.execute(search_name,{'ipr':ipr})
        get_name_sth = ipprocursor.fetchall()
        
        #for each name found print it
        for row in get_name_sth:
            print row[0]
    else:
        print ""        
            
            
            