#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# This script count all the SCOP and CATH new entries integrated into InterPro
#######################################################################################

import os
import sys
import re

#get the arguments
file_name = sys.argv[1]

dirname = os.path.dirname(__file__)
if not dirname:
    dirname = '.'

#get the file
directoryToPrint = dirname +"/unintegrated/"
file_to_check = directoryToPrint+file_name

#open the file to read
my_file = open (file_to_check,'r')

#initialize variables
cath = 0
scop = 0
pairs = 0
new_pairs = 0
previous_cath = ''
previous_scop = ''

#read file
for row in my_file:

    #pattern matching CATH line
    pattern_cath = re.search("G3DSA:\d+\.\d+\.\d+\.\d+",row)
    #pattern matching SCOP line
    pattern_scop = re.search("SSF\d+",row)
    #pattern matching lines containing a date
    pattern_new = re.search("\d\d/\d\d/\d\d\d\d",row)
    #pattern matching lines containing "none" string
    pattern_none = re.search("none",row)
    
    #if the current line corresponds to a CATH entry
    if pattern_cath:
        #if entry newly integrated
        if pattern_new:
            cath+=1
            previous_cath='cath_new'
        #if entry already integrated
        elif pattern_none:
            previous_cath = 'cath'
        else:
            previous_cath = ''       
        previous_scop = ''
        
    #if the current line corresponds to a SCOP entry
    if pattern_scop:
         #if entry newly integrated
        if pattern_new:
            scop+=1
            previous_scop = 'scop_new'
        #if entry already integrated
        elif pattern_none:
            previous_scop = 'scop'
        else:
            previous_scop=''

    # if both new CATH and new SCOP entries => completely new pair
    if previous_cath == 'cath_new' and previous_scop == 'scop_new':
        new_pairs += 1
        previous_cath = ''
        previous_scop = ''
    # if CATH or SCOP new entry => new pair
    elif (previous_cath == 'cath_new' and previous_scop == 'scop') or (previous_cath == 'cath' and previous_scop == 'scop_new'):
        pairs += 1
        previous_cath = ''
        previous_scop = ''

#print results
print "* GENE3D:",cath
print "* SUPERFAMILY:",scop
print "* cluster/pairs:",pairs+new_pairs,"(",new_pairs,"completely new)"
