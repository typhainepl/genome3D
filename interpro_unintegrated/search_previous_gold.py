#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# Comparison of files containing unintegratde InterPro entries for GENE3D and SUPERFAMILY databases
# This script find entries from a file which where not in the previous version of this file
# take 2 arguments in parameters: old_file and new_file to compare
#######################################################################################

import os
import sys
import re

#get the arguments
previous_file = sys.argv[1]
new_file = sys.argv[2]

dirname = os.path.dirname(__file__)
if not dirname:
    dirname = '.'

#files are in the unintegrated directory
directoryToPrint = dirname +"/unintegrated/"
unintegrated_gold_blocks_file = directoryToPrint+new_file
unintegrated_previous = directoryToPrint+previous_file

#open the files to read in
previous = open (unintegrated_previous,'r')
goldFile = open (unintegrated_gold_blocks_file,'r')

gold_new = []
gold_old = []

#get data from the new file
for row in goldFile:
    pattern = re.search("(G3DSA:\d{1}\.\d+\.\d+\.\d+|SSF\d+)",row)
    if pattern:
        gold_new.append(pattern.group(1))

#get data from the old file
for row in previous:
    pattern = re.search("(G3DSA:\d{1}\.\d+\.\d+\.\d+|SSF\d+)",row)
    if pattern:
        gold_old.append(pattern.group(1))

#compare the two files and print the lines which differs
for row in gold_new:
	if row not in gold_old:
		print row

#close files
previous.close()
goldFile.close()
