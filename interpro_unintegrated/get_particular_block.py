#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# For each cluster, this script get particular blocks (gold, one to many domains between cath and scop MDA blocks)
#######################################################################################

import urllib2
import os

import cx_Oracle
import ConfigParser
import sys
import re
import search_unintegrated

number = sys.argv[1]
file_name = sys.argv[2]

dirname = os.path.dirname(__file__)
if not dirname:
    dirname = '.'

file_name = dirname + '/unintegrated/'+file_name

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

def clean_tmp(path):
    os.system('rm -Rf '+path)
    os.system('mkdir '+path)


def getNbBlocks(pdbecursor,clusternode):
    #get the number of blocks in a give cluster
    nbBlock = 0

    getCount = "select count(block) as nb_block from cluster_block_new where cluster_node=:clusternode"
    pdbecursor.execute(getCount,clusternode=clusternode)
    getCount_sth = pdbecursor.fetchall()

    for row in getCount_sth:
        nbBlock = row[0]

    return nbBlock


def haveSameNumberOfDomains(nodes,number):
    #search is same number of CATH and SCOP domains in the block
    number = int(number)
    
    nbCath = 0
    nbScop = 0
    nbDiffCath = 0 
    nbDiffScop = 0
    cath_sf = []
    scop_sf = []

    for domain in nodes:
        if re.match("^[a-z]",domain):
            nbScop+=1
            if number >= 3:
                #search if the block is composed of more than one SCOP sf
                if domain not in scop_sf:
                    nbDiffScop+=1
                    scop_sf.append(domain)
        else:
            nbCath+=1
            if number >= 3:
                if domain not in cath_sf:
                    #search if the block is composed of more than one CATH sf
                    nbDiffCath+=1
                    cath_sf.append(domain)

    #same number of CATH and SCOP domains
    if nbCath == nbScop:
        return "true"
    #in number 2 case we want cases where 2 domains from 1sf corresponds to 1 domain
    elif number == 2 and nbCath > nbScop and nbScop == 1:
        return "more cath"
    elif number == 2 and nbCath < nbScop and nbCath == 1:
        return "more scop"
    #in the number 3 case we only want cases where 2 domains from 2sf corresponds to 1 domain
    elif number == 3 and nbDiffCath == 2 and nbScop == 1:
        return "more cath"
    elif number == 3 and nbDiffScop == 2 and nbCath == 1:
        return "more scop"
    else:
        return "false"




def whiteSpace(pdbecursor,block):
    #search is there is a domain not in this cluster in the block
    getBlockPositions = "select positionCath,positionScop from mda_block_new where block=:block"

    pdbecursor.execute(getBlockPositions,block=block)
    blockpos = pdbecursor.fetchall()

    hasBlank=0

    for row in blockpos:
        positionCath = row[0]
        positionScop = row[1]

        posCath = positionCath.split(None)
        posScop = positionScop.split(None)

        hasBlank+=compareBeginEndDomain(posCath)
        hasBlank+=compareBeginEndDomain(posScop)

    return hasBlank


def compareBeginEndDomain(positions):
    #search is the domains are not continuous
    hasBlank = 0
    if len(positions) > 1:
        for pos in range(len(positions)-1):
            firstdomain = positions[pos].split('-')
            nextdomain = positions[pos+1].split('-')

            endfirst = int(firstdomain[1])
            startsecond = int(nextdomain[0])

            #compare begin next position to end current position
            if startsecond-20 > endfirst:
                hasBlank+=1

    return hasBlank


def getUnintegratedBlocks(pdbecursor, ipprocursor, clusternode, number, unintegrated_file, nodes, unintegrated):

    # get the number of blocks in the cluster
    nbBlock = getNbBlocks(pdbecursor,clusternode)

    toVerify = 0
    seen = []

    # select the different blocks in the cluster
    getBlocks = "select block from cluster_block_new where cluster_node=:clusternode"
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
            if int(number) == 1:
                if haveSameNumberOfDomains(blockDomains,number) == "true":
                    #if only one block in the cluster => GOLD
                    if nbBlock == 1 and clusternode not in seen:

                        toVerify = 1
                        unintegrated['gold_cluster']+=1

            #if one domain in CATH/SCOP corresponds to mulitple domain in SCOP/CATH
            else:
                if haveSameNumberOfDomains(blockDomains,number) == "more cath" or haveSameNumberOfDomains(blockDomains,number) == "more scop":
                    #if there isn't domains with undefined SF in the block
                    if whiteSpace(pdbecursor,block) == 0 and clusternode not in seen:
                        returnValues = search_unintegrated.getUnintegrated(pdbecursor,ipprocursor, nodes, unintegrated_file)

                        unintegrated['counters']['cath']+=returnValues[0]
                        unintegrated['counters']['scop']+=returnValues[1]
                        # notInDb_cath+=returnValues[2]
                        # notInDb_scop+=returnValues[3]
                        unintegrated['counters']['pair']+=returnValues[4]
                        seen.append(clusternode)


    #if same number of domains in CATH and SCOP => GOLD BLOCK
    if toVerify == 1 and int(number) == 1:
        #search unintegrated CATH and SCOP SF in InterPro
        returnValues = search_unintegrated.getUnintegrated(pdbecursor,ipprocursor,nodes,unintegrated_file)

        unintegrated['counters']['cath']+=returnValues[0]
        unintegrated['counters']['scop']+=returnValues[1]
        # # notInDb_cath+=returnValues[2]
        # # notInDb_scop+=returnValues[3]
        unintegrated['counters']['pair']+=returnValues[4]

    return unintegrated

        


def getCluster(pdbecursor,ipprocursor,number,file):
    #get all the clusters with same number of CATH and SCOP SF

    getNodes = "select * from cluster_new order by cluster_node asc"
    pdbecursor.execute(getNodes)
    get_nodes_sth=pdbecursor.fetchall()

    unintegrated = {'gold_cluster':0, 'counters':{'cath':0,'scop':0,'pair':0}}

    for cluster_row in get_nodes_sth:

        nodes = cluster_row[1].split(' ')
        cluster = cluster_row[0]

        nbCath = 0
        nbScop = 0

        for element in nodes:
            if re.match("^[a-z]",element) :
                nbScop+=1
            else:
                nbCath+=1

        #case of same number of CATH and SCOP superfamilies in the cluster
        if int(number) == 1:
            if nbCath == nbScop:
                # for each cluster, get the blocks
                unintegrated = getUnintegratedBlocks(pdbecursor, ipprocursor, cluster, number, file, nodes,unintegrated)

        #case of one CATH and one SCOP superfamily in the cluster
        elif int(number) == 2:
            if nbCath == nbScop and nbCath == 1:
                unintegrated = getUnintegratedBlocks(pdbecursor, ipprocursor, cluster, number, file, nodes,unintegrated)

        #case of two CATH SF for one SCOP, or one CATH SF for 2 SCOP in cluster
        elif int(number) == 3:
            if (nbCath == 2 and nbScop == 1) or (nbCath == 1 and nbScop == 2):
                unintegrated = getUnintegratedBlocks(pdbecursor, ipprocursor, cluster, number, file, nodes,unintegrated)


    return unintegrated


####################
#main program

#clean directory
# TMP = "unintegrated"
# clean_tmp(TMP)

#get cluster and blocks and unintegrated
unintegrated = getCluster(pdbecursor,ipprocursor,number,file_name)

file = open (file_name,'a')

file.write("Resume:\n")
file.write("GENE3D:"+str(unintegrated['counters']['cath'])+"\n")
file.write("SUPERFAMILY:"+str(unintegrated['counters']['scop'])+"\n")
file.write("PAIRS:"+str(unintegrated['counters']['pair']))

# gold_cluster = unintegrated['gold_cluster']

file.close()