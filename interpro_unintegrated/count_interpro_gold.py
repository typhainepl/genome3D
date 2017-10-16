#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# This script get all the SCOP and CATH entries that are not integrated into InterPro signatures
#######################################################################################

import cx_Oracle
import ConfigParser
import re
import os
from scipy.optimize._tstutils import description

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
pdbecursor2 = pdbeconnection.cursor()

#Connexion to interpro database
IPPROUSER=configdata.get('Global', 'ipproUser')
IPPROPASS=configdata.get('Global', 'ipproPass')
IPPROHOST=configdata.get('Global', 'ipproHost')

ipproconnection = cx_Oracle.connect(IPPROUSER+'/'+IPPROPASS+'@'+IPPROHOST)
ipprocursor = ipproconnection.cursor()

def getNbBlocks(pdbecursor,clusternode):
    #get the number of blocks in a give cluster
    nbBlock = 0

    getCount = "select count(block) as nb_block from cluster_block_test where cluster_node=:clusternode"
    pdbecursor.execute(getCount,clusternode=clusternode)
    getCount_sth = pdbecursor.fetchall()

    for row in getCount_sth:
        nbBlock = row[0]

    return nbBlock

def getSSF(pdbecursor,scop):
    #return the scop superfamily id corresponding to the SCCS
    pdbecursor.execute("select distinct superfamily_id,sccs from sifts_admin.SCOP_CLASS")
    request = pdbecursor.fetchall()

    for all_row in request:
        sccs = all_row[1]
        superfamily = all_row[0]

        m = re.match ("(.\.\d+\.\d+)\.",sccs)
        if m:
            sccs = m.group(1)
        
        if sccs == scop:
            return superfamily

    return 0

def getParentChild(ipprocursor, ipr1, ipr2, alone2):
    # search if the parent entry has children
    count = 0
    
    get_parent_child = "select count(*) \
        from interpro.entry2entry \
        where (entry_ac = :ipr or parent_ac = :ipr)"
    # case where SSF and GENE3D integrated alone in distinct entries
    if ipr2 != '' and alone2 == 1:
        get_parent_child+=" and (entry_ac != :iprother or parent_ac != :iprother)"
        ipprocursor.execute(get_parent_child,{'ipr':ipr1,'iprother':ipr2}) or die
    else:
        ipprocursor.execute(get_parent_child,{'ipr':ipr1}) or die
        
    get_parent_sth = ipprocursor.fetchall()
    
    for row_ippro in get_parent_sth:
        if row_ippro[0] != 0:
            count += 1
    
    return count
    
def countSameEntry(pdbecursor,ipprocursor,nodes,counters):

    #get the superfamilies not integrated in InterPro
    get_unintegrated=" select\
        e.entry_ac\
        from interpro.method m\
        left outer join interpro.mv_method_match@iprel was on (m.method_ac= was.method_ac)\
        left outer join interpro.entry2method em on (m.method_ac=em.method_ac)\
        left outer join interpro.entry e on (e.entry_ac=em.entry_ac)\
        where m.dbcode like :dbcode and 1=1 and 1=1 and 1=1 and m.method_ac=:method\
        group by e.entry_ac"
        
    get_number_signatures = "select count(m.method_ac)\
        from interpro.method m\
        left outer join interpro.mv_method_match@iprel was on (m.method_ac= was.method_ac)\
        left outer join interpro.entry2method em on (m.method_ac=em.method_ac)\
        left outer join interpro.entry e on (e.entry_ac=em.entry_ac)\
        where e.entry_ac=:ipr"
        
    iprSSF = iprGENE3D = cluster_node = ''
    nbAloneSSF = nbAloneGENE3D = 0

    for node in nodes:
        if re.match("^[a-z]",node):
            #search corresponding SSF signature
            scopSSF = getSSF(pdbecursor,node)
            scop_search = "SSF"+str(scopSSF)
  
            ipprocursor.execute(get_unintegrated,('Y',scop_search)) or die
            get_unintegrated_sth = ipprocursor.fetchall()
  
            for row_ippro in get_unintegrated_sth:
                #if found signature but no corresponding InterPro identifier => unintegrated
                if row_ippro[0]:
                    iprSSF = str(row_ippro[0])
                    counters['nbSSF'] += 1
                       
                    #search if SSF alone in the InterPro entry
                    ipprocursor.execute(get_number_signatures,{'ipr':iprSSF}) or die
                    get_nb_signatures_sth = ipprocursor.fetchall()
                       
                    for row_nb in get_nb_signatures_sth:
                        if row_nb[0] == 1:
                            counters['nbAloneSSF'] += 1
                            nbAloneSSF = 1
                        #use for cases where SSF and GENE3D in same entry, without other signatures
                        elif row_nb[0] == 2:
                            nbAloneSSF = 2
        else:
            #search corresponding GENE3D signature
            if cluster_node == '':
                cluster_node=node
  
            cath_search = "G3DSA:"+str(node)
  
            ipprocursor.execute(get_unintegrated,('X',cath_search)) or die
            get_unintegrated_sth = ipprocursor.fetchall()
  
            for row_ippro in get_unintegrated_sth:
                #if found signature but no corresponding InterPro entry => unintegrated
                if row_ippro[0]:
                    iprGENE3D = str(row_ippro[0])
                    counters['nbGENE3D'] += 1
                      
                    #search if GENE3D alone in the InterPro entry
                    ipprocursor.execute(get_number_signatures,{'ipr':iprGENE3D}) or die
                    get_nb_signatures_sth = ipprocursor.fetchall()
                      
                    for row_nb in get_nb_signatures_sth:
                        if row_nb[0] == 1:
                            counters['nbAloneGENE3D'] += 1
                            nbAloneGENE3D = 1
                     
         
    # case where SSF and GENE3D in same InterPro entry
    if iprSSF != '' and iprGENE3D != '' and iprSSF == iprGENE3D :
        counters['sameEntry'] += 1
        # case where SSF and GENE3D alone in same entry
        if nbAloneSSF == 2:
            counters['sameEntryAlone'] += 1
        
        counters['nbrelation'] += getParentChild(ipprocursor, iprSSF, '', nbAloneGENE3D)
        
    # case where SSF and GENE3D in different InterPro entries
    elif iprSSF != '' and iprGENE3D != '' and iprSSF != iprGENE3D :
        counters['diffEntry'] += 1
        counters['diffEntryAloneGENE3D'] += nbAloneGENE3D
        counters['diffEntryAloneSSF'] += nbAloneSSF
        #count number of signatures alone in their entry
        if nbAloneGENE3D == 1 and nbAloneSSF == 1:
            counters['diffEntryAlone'] += 1
        
        counters['nbrelation'] += getParentChild(ipprocursor, iprSSF, iprGENE3D, nbAloneGENE3D)
        counters['nbrelation'] += getParentChild(ipprocursor, iprGENE3D, iprSSF, nbAloneSSF)
        
    # case where only SSF integrated or only GENE3D integrated
    if iprSSF != '' and iprGENE3D == '':
        counters['onlyOne'] += 1
        counters['onlySSF'] += 1
        if nbAloneSSF ==1:
            counters['onlySSFAlone'] += 1
        
        counters['nbrelation'] += getParentChild(ipprocursor, iprSSF, '', 0)
        
    # case where only GENE3D integrated
    if iprSSF == '' and iprGENE3D != '':
        counters['onlyOne'] += 1
        counters['onlyGENE3D'] += 1
        if nbAloneGENE3D ==1:
            counters['onlyGENE3DAlone'] += 1
        
        counters['nbrelation'] += getParentChild(ipprocursor, iprGENE3D, '', 0)
        
    # neither GENE3D and SSF integrated
    if (iprSSF=='' and iprGENE3D == ''):
        counters['none'] += 1
    
    
        
    return counters    

        
def getUnintegratedBlocks(pdbecursor, ipprocursor, clusternode, nodes, counters):

    # get the number of blocks in the cluster
    nbBlock = getNbBlocks(pdbecursor,clusternode)

    toVerify = 0

    # select the different blocks in the cluster
    getBlocks = "select block from cluster_block_test where cluster_node=:clusternode"
     
    pdbecursor.execute(getBlocks, clusternode=clusternode)
    getBlocks_sth = pdbecursor.fetchall()

    # get all the blocks in the cluster
    for block_row in getBlocks_sth:
        
        block = block_row[0]
        blockDomains = block.split(' ')

        notInCluster = 0

        for element in blockDomains:
            #search if all the nodes in the block are in the cluster
            if element not in nodes:
                notInCluster+=1

        #if all the SF in the block belongs to the cluster
        if notInCluster == 0:

            #if same number of CATH and SCOP domains
            if haveSameNumberOfDomains(blockDomains) == "true":
                
                #if only one block in the cluster => GOLD
                if nbBlock == 1:
                    toVerify = 1
                    counters['gold_cluster']+=1

    #if same number of domains in CATH and SCOP => GOLD BLOCK
    if toVerify == 1:
        counters = countSameEntry(pdbecursor, ipprocursor, nodes, counters)

    return counters   

def haveSameNumberOfDomains(nodes):
    #search is same number of CATH and SCOP domains in the block
    
    nbCath = 0
    nbScop = 0
    nbDiffCath = 0 
    nbDiffScop = 0

    for domain in nodes:
        if re.match("^[a-z]",domain):
            nbScop+=1
        else:
            nbCath+=1

    #same number of CATH and SCOP domains
    if nbCath == nbScop:
        return "true"
    else:
        return "false"     


def getCluster(pdbecursor,pdbecursor2,ipprocursor):
    #get all the clusters with same number of CATH and SCOP SF

    getNodes = "select * from cluster_test order by cluster_node asc"
    pdbecursor.execute(getNodes)

    counters = {'gold_cluster':0, 'nbSSF':0, 'nbAloneSSF':0, 'nbGENE3D':0, 'nbAloneGENE3D':0, 'sameEntry':0, 'sameEntryAlone':0, 'diffEntry':0, 'diffEntryAlone':0, 'onlySSF':0, 
                'onlyGENE3D':0, 'onlyOne':0, 'none':0, 'diffEntryAloneGENE3D':0, 'diffEntryAloneSSF':0, 'onlySSFAlone':0, 'onlyGENE3DAlone':0, 'nbrelation':0}

    for cluster_row in pdbecursor:
        nodes = cluster_row[1].read().split(' ')
        cluster = cluster_row[0]

        nbCath = 0
        nbScop = 0

        for element in nodes:
            if re.match("^[a-z]",element) :
                nbScop+=1
            elif re.match("^\d+\.\d+$",element):
                nbScop+=1
            else:
                nbCath+=1
 
        #case of same number of CATH and SCOP superfamilies in the cluster
        if nbCath == nbScop:
            # for each cluster, get the blocks
            counters = getUnintegratedBlocks(pdbecursor2, ipprocursor, cluster, nodes,counters)
 
    return counters
    
########## Main program #########

totalCount = getCluster(pdbecursor, pdbecursor2, ipprocursor)
print totalCount


