#!/usr/bin/env python

import urllib2
import os
import cx_Oracle

import re
import ConfigParser

import sys

dirname = os.path.dirname(__file__)
if not dirname:
    dirname = '.'
    
sys.path.insert(0,'/nfs/msd/work2/sifts_newDB/update_xref_databases/common/')

from common import dosql

# config = ConfigParser.RawConfigParser()
# config.read(dirname + '/../db.cfg')

USER='typhaine'
PASS='typhaine55'
HOST='pdbe_test'

# schema='SIFTS_ADMIN'
tables=['ECOD_DESCRIPTION','ECOD_COMMENT','SEGMENT_ECOD']

REPO='http://prodata.swmed.edu/ecod/distributions/ecod.latest.domains.txt'
VERSION='1.4'

TMP='ecod_tmp'

t_description='CREATE TABLE ECOD_DESCRIPTION_NEW ( \
    "UID"         NUMBER(38,0) NOT NULL ENABLE, \
    "F_ID"        VARCHAR2(20 BYTE), \
    "DOMAIN_ID"   VARCHAR2(20 BYTE), \
    "A_NAME"      VARCHAR2(500 BYTE), \
    "X_NAME"      VARCHAR2(500 BYTE), \
    "H_NAME"      VARCHAR2(500 BYTE), \
    "T_NAME"      VARCHAR2(500 BYTE), \
    "DESCRIPTION" VARCHAR2(2400 BYTE) \
    )'
    
comment='CREATE TABLE ECOD_COMMENT_NEW ( \
        "UID"      NUMBER(38,0) NOT NULL ENABLE, \
        "ORDINAL"  NUMBER(38,0) NOT NULL ENABLE, \
        "LIGAND"   VARCHAR2(2000 BYTE), \
        "CURATION" VARCHAR2(20 BYTE) \
      )'
          
classtable='CREATE TABLE SEGMENT_ECOD_NEW ( \
              "UID"          NUMBER(38,0) NOT NULL ENABLE, \
              "ENTRY"        VARCHAR2(4 BYTE) NOT NULL ENABLE, \
              "DOMAIN"    VARCHAR2(20 BYTE), \
              "ORDINAL"      NUMBER(38,0) NOT NULL ENABLE, \
              "AUTH_ASYM_ID" VARCHAR2(4 BYTE), \
              "START" NUMBER(38,0), \
              "END"	 NUMBER(38,0), \
              "LENGTH"       NUMBER(38,0), \
              "SSF"         VARCHAR2(20 BYTE), \
              "F_NAME"       VARCHAR2(1000 BYTE), \
              "BEG_SEQ"      NUMBER(38,0), \
              "BEG_INS_CODE" VARCHAR2(1 BYTE), \
              "END_SEQ"      NUMBER(38,0), \
              "END_INS_CODE" VARCHAR2(1 BYTE) \
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

def find_seq(comment_list,class_list,submpdb,subseqid,ordinal,uid,domain_id,pdb,f_id,f_name,rep):
    
    chain = submpdb.group(1)
    
    begin = submpdb.group(2)
    end = submpdb.group(3)
    beg_ins_code = None
    end_ins_code = None

    if subseqid != None:
        seqid_begin = subseqid.group(2)
        seqid_end = subseqid.group(3)
        length = int(seqid_end)-int(seqid_begin)+1
    else:
        seqid_begin = None
        seqid_end = None
        length = None
    
    if begin[-1].isalpha():
        beg_ins_code=begin[-1]
        begin=begin[:-1]
    
    if end[-1].isalpha():
        end_ins_code=end[-1]
        end=end[:-1]
    
    class_obj = (uid,pdb,domain_id,ordinal,chain,seqid_begin,seqid_end,length,f_id,f_name,begin,beg_ins_code,end,end_ins_code)
    class_list.append(class_obj)
    comment_obj = (uid,ordinal,ligand,rep)
    comment_list.append(comment_obj)

    return chain
    

### MAIN program ###

#database connexion
connection = cx_Oracle.connect(USER+'/'+PASS+'@'+HOST)
cursor=connection.cursor()
             
#clean repertory
clean_tmp(TMP)

#drop old tables and create new ones
for t in tables:
    if not dosql(cursor,'DROP TABLE '+t+'_NEW'):
        cursor.close()
        connection.close()
        sys.exit(-1)

connection.commit()

for t in [t_description,comment,classtable]:
    if not dosql(cursor,t):
        cursor.close()
        connection.close()
        sys.exit(-1)
    
connection.commit()   
  
#get the data
desc=download_file(REPO,TMP)

# desc = dirname+'/'+TMP+'/ecod.latest.domains.txt'
fdesc=open(desc)

desc_list=[]
comments_list=[]
class_list=[]
nb = 0

for row in fdesc.readlines():
    if row[0]=='#':
        continue
    
    ordinal = 1
    chains = []
    
#         print row /
    #remove double quotes
    row = row.replace('"','')
    #get the data
    uid,domain_id,rep,f_id,pdb,chain,pdb_range,seqid_range,a_name,x_name,h_name,t_name,f_name,description,ligand = row.split('\t',14)
    
    # replace values by none if no information given by ECOD
    if ligand == 'NO_LIGANDS_4A': ligand = None
    else : ligand = ligand.rstrip("\n")
    
    if description == 'NOT_DOMAIN_ASSEMBLY': description = None
    if a_name == 'NO_A_NAME': a_name = None
    if x_name == 'NO_X_NAME': x_name = None
    if h_name == 'NO_H_NAME': h_name = None
    if t_name == 'NO_T_NAME': t_name = None
    if f_name == 'NO_F_NAME' or f_name == 'F_UNCLASSIFIED': f_name = None
  
    # fill comment list and class list
    # patterns to get the chain and begin and end positions
    pattern = '([A-Z]:-?\d{1,}[A-Z]?--?\d{1,}[A-Z]?),?([A-Z]:-?\d{1,}--?\d{1,})?,?([A-Z]:-?\d{1,}--?\d{1,})?'
    subpattern = '([A-Z]):(-?\d{1,}[A-Z]?)-(-?\d{1,}[A-Z]?)'
    
    mpdb = re.search(pattern,pdb_range)
    seq_id = re.search(pattern,seqid_range)
    if mpdb:
        # if the pattern is found, get chains, begin, end positions and insertions
        submpdb = re.search(subpattern,mpdb.group(1))
        subseqid = re.search(subpattern,seq_id.group(1))
        chain = find_seq(comments_list,class_list,submpdb,subseqid,ordinal,uid,domain_id,pdb,f_id,f_name,rep)
        
        if mpdb.group(2):
            #if more than one chain
            submpdb = re.search(subpattern,mpdb.group(2))
            if seq_id.group(2):
                subseqid = re.search(subpattern,seq_id.group(2))
            else: 
                subseqid = None
            # if the previous chain has the same letter than the current one, increase the ordinal number
            if chain == submpdb.group(1):
                ordinal += 1
            # get chains, begin, end positions and insertions
            chain = find_seq(comments_list,class_list,submpdb,subseqid,ordinal,uid,domain_id,pdb,f_id,f_name,rep)

        if mpdb.group(3):
            #if more than one chain
            submpdb = re.search(subpattern,mpdb.group(3))
            if seq_id.group(3):
                subseqid = re.search(subpattern,seq_id.group(3))
            else: 
                subseqid = None
            # if the previous chain has the same letter than the current one, increase the ordinal number
            if chain == submpdb.group(1) or chain == submpdb.group(2):
                ordinal += 1
            # get chains, begin, end positions and insertions
            find_seq(comments_list,class_list,submpdb,subseqid,ordinal,uid,domain_id,pdb,f_id,f_name,rep)

    #description list
    desc_obj = (uid,f_id,domain_id,a_name,x_name,h_name,t_name,description)
    desc_list.append(desc_obj)
        

fdesc.close()
print "parsing ok"
# print class_list

print "insert data into %s_NEW table" % (tables[0])
cursor.executemany('INSERT INTO %s VALUES(:1,:2,:3,:4,:5,:6,:7,:8)' % (tables[0]+'_NEW'),desc_list)
print "insert data into %s_NEW table" % (tables[1])
cursor.executemany('INSERT INTO %s VALUES(:1,:2,:3,:4)' % (tables[1]+'_NEW'),comments_list)
print "insert data into %s_NEW table" % (tables[2])
cursor.executemany('INSERT INTO %s VALUES(:1,:2,:3,:4,:5,:6,:7,:8,:9,:10,:11,:12,:13,:14)' % (tables[2]+'_NEW'),class_list)

connection.commit()



