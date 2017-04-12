#!/usr/bin/env python

##
# @author J.M. Dana, T. Paysan-Lafosse
# @brief This script creates CATH tables, next used by SIFTS and PDBe website
##

import urllib2
import os

import cx_Oracle
import sys
import gzip
import re
import time

dirname = os.path.dirname(__file__)
if not dirname:
	dirname = '.'

sys.path.insert(0,'/nfs/msd/work2/sifts_newDB/update_xref_databases/common/')

from common import dosql

REPO = "http://download.cathdb.info/cath/releases/daily-release/newest/"
NAMES_GZ = REPO + "cath-b-newest-names.gz"
DOMAIN_DESC_GZ = REPO + "cath-b-newest-all.gz"
TMP='cath_tmp'

USER='typhaine'
PASS='typhaine55'
HOST='pdbe_test'

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

#get current date
datestart = time.strftime("%x")
print "Cath b update started %s \n" %(datestart)

clean_tmp(TMP)

names=download_file(NAMES_GZ,TMP)
domains=download_file(DOMAIN_DESC_GZ,TMP)

connection = cx_Oracle.connect(USER+'/'+PASS+'@'+HOST)
cursor=connection.cursor()

for t in tables:
	if not dosql(cursor,'DROP TABLE '+t+'_NEW'):
		cursor.close()
		connection.close()
		sys.exit(-1)

connection.commit()

if not dosql(cursor,name):
	cursor.close()
	connection.close()
	sys.exit(-1)
	
if not dosql(cursor,domain):
	cursor.close()
	connection.close()
	sys.exit(-1)
	
if not dosql(cursor,segment):
	cursor.close()
	connection.close()
	sys.exit(-1)


connection.commit()


# enter data in CATH_B_NAME table 
print "insert data into %s_NEW table" % (tables[0])

fnames=open(names)

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

cursor.executemany('INSERT INTO %s VALUES(:1,:2)' % (tables[0]+'_NEW'),nodes)
connection.commit()

fnames.close()



#get the description corresponding to the number from CATH_DOMAIN for class, architecture, topology and homology superfamily
cursor.execute("select distinct(cathcode),class,arch,topol,homol from CATH_DOMAIN");
cathinfo = cursor.fetchall();

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

fdomains=open(domains)
domains=[]
segments=[]

print "Get data from files"
cursor.prepare("select name,source from CATH_DOMAIN where domain= :domain")
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
	cursor.execute(None, domain = domain);
	for d in cursor:
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
	cursor.setinputsizes(*inputsizes)
	cursor.executemany('INSERT INTO %s VALUES(:1,:2,:3,:4,:5,:6,:7,:8,:9,:10,:11)' % (tables[1]+'_NEW'),domains[i:i+100])
	i+=100

connection.commit()    

print "insert data into %s_NEW table" % (tables[2])

cursor.executemany('INSERT INTO %s VALUES(:1,:2,:3,:4,:5,:6,:7,:8)' % (tables[2]+'_NEW'),segments)
connection.commit()    


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
	if not dosql(cursor,command):
		cursor.close()
		connection.close()
		sys.exit(-1)
	

connection.commit()   

print "End update\n"

cursor.close()
connection.close()
