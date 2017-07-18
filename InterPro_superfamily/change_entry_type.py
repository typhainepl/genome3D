#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# This script updates the type of InterPro entries from a given list to 'Homologous superfamily'
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

#initialize variables
entry_type = 'H'
name=''
short_name=''
checked=''
remark = "change entry type to Homologous superfamily"
action = 'U'

#get the current date
time = time.strftime("%d-%b-%y").upper()

#get the file to read
file_name = sys.argv[1]
file_location = './'+file_name

my_file = open (file_location,'r')

#requests
update_type = "update interpro.entry set entry_type='H', timestamp=:time, userstamp=:userstamp  where entry_ac=:entry_ac"
 
for line in my_file:
    pattern_entry = re.search("IPR",line)
     
    entry = line.strip()
     
    if pattern_entry:
        #change the entry type
        ipprocursor.execute(update_type,{'entry_ac':entry,'time':time,'userstamp':IPPROUSER})
        ipproconnection.commit()

        
        
        
        