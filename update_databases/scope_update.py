#!/usr/bin/env python

import urllib2
import os
import cx_Oracle
import re
import ConfigParser
import sys
import time
	
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


# schema='SIFTS_ADMIN'
tables=['SCOPE_DESCRIPTION','SCOPE_COMMENT','SCOPE_HIERARCHY','SCOPE_CLASS']

# REPO='https://scop.berkeley.edu/downloads/parse/'
# VERSION='2.06'
# 
# DESC_REPO=REPO+'dir.des.scope.'+VERSION+'-stable.txt'
# CLASS_REPO=REPO+'dir.cla.scope.'+VERSION+'-stable.txt'
# HIERARCHY_REPO=REPO+'dir.hie.scope.'+VERSION+'-stable.txt'
# COMMENTS_REPO=REPO+'dir.com.scope.'+VERSION+'-stable.txt'

# NEW UPDATE OF SCOPE (06/04/2017)
REPO='https://scop.berkeley.edu/downloads/update/'
UPDATE = '-2017-04-06'
VERSION='2.06'

DESC_REPO=REPO+'dir.des.scope.'+VERSION+UPDATE+'.txt'
CLASS_REPO=REPO+'dir.cla.scope.'+VERSION+UPDATE+'.txt'
HIERARCHY_REPO=REPO+'dir.hie.scope.'+VERSION+UPDATE+'.txt'
COMMENTS_REPO=REPO+'dir.com.scope.'+VERSION+UPDATE+'.txt'

TMP='scop_tmp'

t_description='CREATE TABLE SCOPE_DESCRIPTION_NEW ( \
	"SUNID"       NUMBER(38,0) NOT NULL ENABLE, \
	"ENTRY_TYPE"  VARCHAR2(2 BYTE), \
	"SCCS"        VARCHAR2(20 BYTE), \
	"SCOP_ID"     VARCHAR2(8 BYTE), \
	"DESCRIPTION" VARCHAR2(240 BYTE) \
	)'
	
comment='CREATE TABLE SCOPE_COMMENT_NEW ( \
		"SUNID"        NUMBER(38,0) NOT NULL ENABLE, \
		"ORDINAL"      NUMBER(38,0) NOT NULL ENABLE, \
		"COMMENT_TEXT" VARCHAR2(2000 BYTE) \
	  )'

hierarchy='CREATE TABLE SCOPE_HIERARCHY_NEW ( \
		  "SUNID"      NUMBER(38,0) NOT NULL ENABLE, \
		  "PARENT_ID"  NUMBER(38,0), \
		  "CHILDS_IDS" CLOB \
		  )'
		  
classtable='CREATE TABLE SCOPE_CLASS_NEW ( \
			  "SCOP_ID"        VARCHAR2(8 BYTE), \
			  "ENTRY"          VARCHAR2(4 BYTE), \
			  "ORDINAL"        NUMBER(38,0) NOT NULL ENABLE, \
			  "AUTH_ASYM_ID"   VARCHAR2(4 BYTE), \
			  "BEG_SEQ"        NUMBER(38,0), \
			  "BEG_INS_CODE"   VARCHAR2(1 BYTE), \
			  "END_SEQ"        NUMBER(38,0), \
			  "END_INS_CODE"   VARCHAR2(1 BYTE), \
			  "SCCS"           VARCHAR2(20 BYTE), \
			  "SUNID"          NUMBER(38,0) NOT NULL ENABLE, \
			  "CLASS_ID"       NUMBER(38,0), \
			  "FOLD_ID"        NUMBER(38,0), \
			  "SUPERFAMILY_ID" NUMBER(38,0), \
			  "FAMILY_ID"      NUMBER(38,0), \
			  "DOMAIN_ID"      NUMBER(38,0) NOT NULL ENABLE, \
			  "SPECIES_ID"     NUMBER(38,0), \
			  "PROTEIN_ID"     NUMBER(38,0) \
			  )'


def clean_tmp(path):
	os.system('rm -Rf '+path)
	os.system('mkdir '+path)
	
def get_filename(url,path):
	return path+'/'+url.split('/')[-1]
	
def download_file(url,path):    
	req=urllib2.Request(url)
	filename=get_filename(url,path)
	
	try:
		data=urllib2.urlopen(req)
		
		f=open(filename,'w')
		f.write(data.read())
		f.close()
	except Exception, e:
		print e
		
	return filename
			
			
### MAIN program ###
		
#get current date
datestart = time.strftime("%d/%m/%Y at %H:%M:%S")
print "##### SCOPE update started %s #####" %(datestart)

#clean repertory
clean_tmp(TMP)

#drop old tables and create new ones
for t in tables:
	if not dosql(pdbecursor,'DROP TABLE '+t+'_NEW'):
		pdbecursor.close()
		pdbeconnection.close()
		sys.exit(-1)
	# if not dosql(pdbecursor,'ALTER TABLE '+t+'_NEW rename to '+t+'_OLD'):
	# 	pdbecursor.close()
	# 	pdbeconnection.close()
	# 	sys.exit(-1)

pdbeconnection.commit()

for t in [t_description,comment,hierarchy,classtable]:
	if not dosql(pdbecursor,t):
		pdbecursor.close()
		pdbeconnection.close()
		sys.exit(-1)
	
pdbeconnection.commit()   


## description ##
print "insert data into %s_NEW table" % (tables[0])

#download new data
desc=download_file(DESC_REPO,TMP)
fdesc=open(desc)

desc_list=[]

for row in fdesc.readlines():
	if row[0]=='#':
		continue
	
	sunid,entry_type,sccs,scop_id,description=row.strip().split(None,4)
	
	obj=(sunid,entry_type,sccs,scop_id,description)

	desc_list.append(obj)

fdesc.close()

pdbecursor.executemany('INSERT INTO %s VALUES(:1,:2,:3,:4,:5)' % (tables[0]+'_NEW'),desc_list)
pdbeconnection.commit()



## comments ##
print "insert data into %s_NEW table" % (tables[1])

#download new data
comments=download_file(COMMENTS_REPO,TMP)
fcomments=open(comments)

comments_list=[]

for row in fcomments.readlines():
	if row[0]=='#':
		continue
	
	sunid,ordinal,comment_text=row.strip().split(None,2)
	
	comment_text=comment_text.split('!')
	
	
	for (comment,ordinal) in zip(comment_text,range(len(comment_text))):
		obj=(sunid,ordinal+1,comment.lstrip())
		comments_list.append(obj)         

fcomments.close()

pdbecursor.executemany('INSERT INTO %s VALUES(:1,:2,:3)' % (tables[1]+'_NEW'),comments_list)
pdbeconnection.commit()



## hierarchy ##
print "insert data into %s_NEW table" % (tables[2])	

#download new data
hierarchy=download_file(HIERARCHY_REPO,TMP)
fhierarchy=open(hierarchy)

hierarchy_list=[]

for row in fhierarchy.readlines():
	if row[0]=='#':
		continue
	
	sunid,parent_id,childs=row.strip().split(None,2)
	
	if parent_id == '-':
		parent_id = None
	
	obj=(sunid,parent_id,childs)
	
	hierarchy_list.append(obj)

fhierarchy.close()


inputsizes=[None] * 3
inputsizes[2]=cx_Oracle.CLOB

i = 0

# The database can't deal with the CLOBs (hangs!!!) so I have insert 100 at a time... 
while i < len(hierarchy_list):
	pdbecursor.setinputsizes(*inputsizes)
	pdbecursor.executemany('INSERT INTO %s VALUES(:1,:2,:3)' % (tables[2]+'_NEW'),hierarchy_list[i:i+100])
	i+=100

pdbeconnection.commit()



## classification ##
print "insert data into %s_NEW table" % (tables[3])

#download new data
classification=download_file(CLASS_REPO,TMP)
fclass=open(classification)

class_list=[]


for row in fclass.readlines():
	if row[0]=='#':
		continue
	
	scop_id,entry_id,asym_id_range,sccs,sunid,classes=row.strip().split(None,5)

	ordinal=1    
	
	if ',' in asym_id_range:
		chains=asym_id_range.split(',')
	else:
		chains=[asym_id_range]
		
	for c in chains:
		auth_asym_id='-'
		begin=None
		end=None
		beg_ins_code=None
		end_ins_code=None
		
		if c != '-':
			auth_asym_id=c.split(':')[0]
	
			if '-' in c:
				limit = c.split(':')[1]
				m = re.match(r"(-?\d+[A-Z]?)-(-?\d+[A-Z]?)",limit)

				begin = m.group(1)
				end = m.group(2)
				
				if begin[-1].isalpha():
					beg_ins_code=begin[-1]
					begin=begin[:-1]

				if end[-1].isalpha():
					end_ins_code=end[-1]
					end=end[:-1]
		
		classes_split=classes.split(',')
		
		obj = (scop_id,entry_id,ordinal,auth_asym_id,begin,beg_ins_code,end,end_ins_code,sccs,sunid,
				classes_split[0].split('=')[1],
				classes_split[1].split('=')[1],
				classes_split[2].split('=')[1],
				classes_split[3].split('=')[1],
				classes_split[4].split('=')[1],
				classes_split[5].split('=')[1],
				classes_split[6].split('=')[1]
				)

		class_list.append(obj)		
		
		ordinal+=1

fclass.close()


pdbecursor.executemany('INSERT INTO %s VALUES(:1,:2,:3,:4,:5,:6,:7,:8,:9,:10,:11,:12,:13,:14,:15,:16,:17)' % (tables[3]+'_NEW'),class_list)
pdbeconnection.commit()

SQL="drop table " + tables[0] +";\
	drop table " + tables[1] +";\
	drop table " + tables[2] +";\
	drop table " + tables[3] +";\
	alter table " + tables[0] + "_NEW rename to " + tables[0] + ";\
	alter table " + tables[1] + "_NEW rename to " + tables[1] + ";\
	alter table " + tables[2] + "_NEW rename to " + tables[2] + ";\
	alter table " + tables[3] + "_NEW rename to " + tables[3] + ";\
	commit;"

# 	CREATE INDEX scop_class_entry_auth ON SCOPE_CLASS(entry,auth_asym_id) tablespace SIFTS_ADMIN_I;\
# 	CREATE INDEX scop_class_entry_auth_id ON SCOPE_CLASS(entry,auth_asym_id,scop_id) tablespace SIFTS_ADMIN_I;\
# 	CREATE INDEX scop_class_id ON SCOPE_CLASS(scop_id) tablespace SIFTS_ADMIN_I;\
# 	CREATE INDEX scop_desc_id ON SCOPE_DESCRIPTION(scop_id) tablespace SIFTS_ADMIN_I;\
# 	commit;"


for command in SQL.split(';')[:-1]:
	if not dosql(pdbecursor,command):
		pdbecursor.close()
		pdbeconnection.close()
		sys.exit(-1)

pdbeconnection.commit()

print "End update SCOPE\n"
# print "Description: %d" % len(desc_list)    
# print "Comments: %d" % len(comments_list)
# print "Hierarchy: %d" % len(hierarchy_list)
# print "Class: %d" % len(class_list)

pdbecursor.close()
pdbeconnection.close()



