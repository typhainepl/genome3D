#!/usr/bin/env python

##
# @author J.M. Dana, T. Paysan-Lafosse
# @brief This script creates CATH_b tables, next used by SIFTS and PDBe website
##

import urllib2
import os
import cx_Oracle
import sys
import gzip
import re
import time
import ConfigParser

sys.path.insert(0,'/Users/typhaine/Desktop/genome3D/config/')
sys.path.insert(0,'/nfs/msd/work2/typhaine/genome3D/config/')

from config import dosql

configdata = ConfigParser.RawConfigParser()
configdata.read([os.path.expanduser('~/Desktop/genome3D/config/db.cfg'), '/nfs/msd/work2/typhaine/genome3D/config/db.cfg'])

#Connexion to PDBE_TEST database
PDBEUSER=configdata.get('Global', 'pdbeUser')
PDBEPASS=configdata.get('Global', 'pdbePass')
PDBEHOST=configdata.get('Global', 'pdbeHost')

pdbeconnection = cx_Oracle.connect(PDBEUSER+'/'+PDBEPASS+'@'+PDBEHOST)
pdbecursor = pdbeconnection.cursor()

REPO = "http://download.cathdb.info/cath/releases/daily-release/newest/"
NAMES_GZ = REPO + "cath-b-newest-names.gz"
DOMAIN_DESC_GZ = REPO + "cath-b-newest-all.gz"
TMP='cath_tmp'

tables=['CATH_B_NAME','CATH_B_DOMAIN','CATH_B_SEGMENT']

name='CREATE TABLE "CATH_B_NAME_NEW" ( \
	"CATHCODE" VARCHAR2(20 BYTE) NOT NULL ENABLE, \
	"NAME"     VARCHAR2(1000 BYTE) \
  )'
domain='CREATE TABLE "CATH_B_DOMAIN_NEW" ( \
	  "DOMAIN"       VARCHAR2(10 BYTE) NOT NULL ENABLE, \
	  "ENTRY_ID"        VARCHAR2(4 BYTE) NOT NULL ENABLE, \
	  "AUTH_ASYM_ID" VARCHAR2(5 BYTE), \
	  "CATHCODE"     VARCHAR2(20 BYTE) NOT NULL ENABLE, \
	  "NSEGMENTS"    NUMBER(38,0) NOT NULL ENABLE, \
	  "NAME"         CLOB, \
	  "SOURCE"       CLOB, \
	  "CLASS"        VARCHAR2(500 BYTE), \
	  "ARCH"         VARCHAR2(500 BYTE), \
	  "TOPOL"        VARCHAR2(500 BYTE), \
	  "HOMOL"        VARCHAR2(500 BYTE) \
  	)'
	
segment='CREATE TABLE "CATH_B_SEGMENT_NEW" ( \
		"DOMAIN"       VARCHAR2(10 BYTE) NOT NULL ENABLE,\
		"ENTRY_ID"        VARCHAR2(4 BYTE) NOT NULL ENABLE,\
		"AUTH_ASYM_ID" VARCHAR2(5 BYTE),\
		"BEG_SEQ"      NUMBER(38,0),\
		"BEG_INS_CODE" VARCHAR2(1 BYTE),\
		"END_SEQ"      NUMBER(38,0),\
		"END_INS_CODE" VARCHAR2(1 BYTE),\
		"ORDINAL"      NUMBER(38,0) NOT NULL ENABLE\
	  )'

def clean_tmp(path):
	os.system('rm -Rf '+path)
	os.system('mkdir '+path)

def get_filename(url,path):
	return path+'/'+url.split('/')[-1]

def download_file(url,path):    
	req=urllib2.Request(url)
	filenamegz=get_filename(url,path)
	filename = filenamegz.split('.')[0]+'.txt'

	print 'Downloading %s to %s' %(url,filenamegz)
	
	try:
		# get the archive file
		data=urllib2.urlopen(req)
		f=open(filenamegz,'w')
		f.write(data.read())
		f.close()

		# extract data from the archive file and put them in a .txt file
		ftxt = open(filename,'w')
		with gzip.open(filenamegz) as f:
			ftxt.write(f.read())
		ftxt.close()
	except Exception, e:
		print e

	return filename        

### MAIN program ###

#get current date
datestart = time.strftime("%d/%m/%Y at %H:%M:%S")
print "##### Cath b update started %s #####" %(datestart)

#clean repertory
clean_tmp(TMP)

#download new data
names_file=download_file(NAMES_GZ,TMP)
domains_file=download_file(DOMAIN_DESC_GZ,TMP)

#drop old tables and create new ones
# for t in tables:
# 	if not dosql(pdbecursor,'DROP TABLE '+t+'_NEW'):
# 		pdbecursor.close()
# 		pdbeconnection.close()
# 		sys.exit(-1)
# 
# pdbeconnection.commit()

if not dosql(pdbecursor,name):
	pdbecursor.close()
	pdbeconnection.close()
	sys.exit(-1)
	
if not dosql(pdbecursor,domain):
	pdbecursor.close()
	pdbeconnection.close()
	sys.exit(-1)
	
if not dosql(pdbecursor,segment):
	pdbecursor.close()
	pdbeconnection.close()
	sys.exit(-1)


pdbeconnection.commit()


# enter data in CATH_B_NAME table 
print "insert data into %s_NEW table" % (tables[0])

fnames=open(names_file)

nodes=[]

for row in fnames.readlines():
	tmp = row.strip().split(None,1)
	cath_id = tmp[0]
	if len(tmp)>1:
		cath_name = tmp[1]
	else:
		cath_name = None


	obj=(cath_id,cath_name)

	nodes.append(obj)

pdbecursor.executemany('INSERT INTO %s VALUES(:1,:2)' % (tables[0]+'_NEW'),nodes)
pdbeconnection.commit()

fnames.close()

#get the description corresponding to the number from CATH_DOMAIN for class, architecture, topology and homology superfamily
pdbecursor.execute("select distinct(cathcode),class,arch,topol,homol from CATH_DOMAIN");
cathinfo = pdbecursor.fetchall();

homologies = {}
classes = {}
architectures = {}
topologies = {}

for cn in cathinfo:
	cathhomol = cn[0]
	cathtmp   = cathhomol.split('.')
	cathclass = cathtmp[0]
	catharch  = cathclass+'.'+cathtmp[1]
	cathtopol = catharch+'.'+cathtmp[2]

	homologies[cathhomol]   = cn[4]
	classes[cathclass]      = cn[1]
	architectures[catharch] = cn[2]
	topologies[cathtopol]   = cn[3]


# Enter data in CATH_SEGMENT and CATH_DOMAIN tables
print "insert data into %s_NEW and %s_NEW tables" % (tables[1],tables[2])

fdomains=open(domains_file)
domains=[]
segments=[]

print "Get data from files"
pdbecursor.prepare("select name,source from CATH_DOMAIN where domain= :domain")
# Read data from all.txt file
for row in fdomains.readlines():
	# data for domain table
	domain,cathrelease,cathcode,segments_list = row.strip().split(None,4)

	# get description from old table CATH_DOMAIN
	cathtmp   = cathcode.split(".")
	cathclass = cathtmp[0]
	catharch  = cathclass+'.'+cathtmp[1]
	cathtopol = catharch+'.'+cathtmp[2]

	homol  = homologies[cathcode] if cathcode in homologies.keys() else None
	classe = classes[cathclass] if cathclass in classes.keys() else None
	arch   = architectures[catharch] if catharch in architectures.keys() else None
	topol  = topologies[cathtopol] if cathtopol in topologies.keys() else None

	segments_list = segments_list.split(',')

	name = None
	source = None

	# get name and source from CATH_DOMAIN
	pdbecursor.execute(None, domain = domain)
	for d in pdbecursor:
		name = d[0].read()
		source = d[1].read()
	
	obj = (domain,domain[0:4],domain[4],cathcode,len(segments_list),name,source,classe,arch,topol,homol)

	domains.append(obj)


	# data for segment table
	for i in range(len(segments_list)):
		begin = None
		end = None
		begin_ins = None
		end_ins = None

		segment = segments_list[i].split(':')[0]

		m = re.match(r'(-?\d+[A-Z]?)-(-?\d+[A-Z]?)',segment)

		begin = m.group(1)
		end = m.group(2)
				
		if(begin[-1].isalpha()):
			begin_ins = begin[-1]
			begin = begin[:-1]
		
		if(end[-1].isalpha()):
			end_ins = end[-1]
			end = end[:-1]
		
		begin = int(begin)
		end = int(end)

		obj=(domain,domain[0:4],domain[4],begin,begin_ins,end,end_ins,i+1)

		segments.append(obj)


fdomains.close()

# Insert data in CATH_DOMAIN and CATH_SEGMENT tables
inputsizes=[None] * 11
inputsizes[5]=cx_Oracle.CLOB
inputsizes[6]=cx_Oracle.CLOB

i = 0

print "insert data into %s_NEW table" % (tables[1])

# The database can't deal with the CLOBs (hangs!!!) so I have insert 100 at a time... 
while i < len(domains):
	pdbecursor.setinputsizes(*inputsizes)
	pdbecursor.executemany('INSERT INTO %s VALUES(:1,:2,:3,:4,:5,:6,:7,:8,:9,:10,:11)' % (tables[1]+'_NEW'),domains[i:i+100])
	i+=100

pdbeconnection.commit()    

print "insert data into %s_NEW table" % (tables[2])

pdbecursor.executemany('INSERT INTO %s VALUES(:1,:2,:3,:4,:5,:6,:7,:8)' % (tables[2]+'_NEW'),segments)
pdbeconnection.commit()    


SQL="drop table " + tables[0] +";\
    drop table " + tables[1] +";\
    drop table " + tables[2] +";\
    alter table " + tables[0] + "_NEW rename to " + tables[0] + ";\
    alter table " + tables[1] + "_NEW rename to " + tables[1] + ";\
    alter table " + tables[2] + "_NEW rename to " + tables[2] + ";\
    commit;"
#add indexes
# SQL="CREATE INDEX cath_domain_entry_auth ON CATH_B_DOMAIN(entry_id,auth_asym_id) tablespace SIFTS_ADMIN_I;\
#     CREATE INDEX cath_domain_entry_domain ON CATH_B_DOMAIN(domain) tablespace SIFTS_ADMIN_I;\
#     CREATE INDEX CATH_DOMAIN_CATHCODE ON CATH_B_DOMAIN(CATHCODE) tablespace SIFTS_ADMIN_I;\
#     CREATE INDEX cath_seg_ent_auth ON CATH_B_SEGMENT(entry_id,auth_asym_id) tablespace SIFTS_ADMIN_I;\
#     CREATE INDEX cath_seg_ent_auth_dom ON CATH_B_SEGMENT(entry_id,auth_asym_id,domain) tablespace SIFTS_ADMIN_I;\
#     CREATE INDEX cath_seg_domain ON CATH_B_SEGMENT(domain) tablespace SIFTS_ADMIN_I;\
#     commit;"
	
for command in SQL.split(';')[:-1]:
	if not dosql(pdbecursor,command):
		pdbecursor.close()
		pdbeconnection.close()
		sys.exit(-1)
	

pdbeconnection.commit()   

print "End update CATH-b\n"

pdbecursor.close()
pdbeconnection.close()
