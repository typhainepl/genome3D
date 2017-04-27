#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# Comparison of files containing unintegratde InterPro entries for GENE3D and SUPERFAMILY databases
# This script find entries from a file which where not in the previous version of this file
# take 2 arguments in parameters: old_file and new_file to compare
#######################################################################################

import urllib2
import os

import ConfigParser
import sys
import re
import search_unintegrated

previous_file = sys.argv[1]
new_file = sys.argv[2]
dirname = os.path.dirname(__file__)
if not dirname:
    dirname = '.'

directoryToPrint = dirname +"/unintegrated/"
unintegrated_gold_blocks_file = directoryToPrint+new_file
unintegrated_previous = directoryToPrint+previous_file

previous = open (unintegrated_previous,'r')
goldFile = open (unintegrated_gold_blocks_file,'r')

gold_new = []
gold_old = []

for row in goldFile:
    pattern = re.search("(\d{1}\.\d+\.\d+\.\d+)",row)
    if pattern:
        if pattern.group(1) not in gold_new:
#             print pattern.group(1)
            gold_new.append(pattern.group(1))

for row in previous:
    pattern = re.search("(\d{1}\.\d+\.\d+\.\d+)",row)
    if pattern:
#         print pattern.group(1)
        gold_old.append(pattern.group(1))
# print gold_old

for row in gold_new:
    # print row
    if row in gold_old:
        print row


previous.close()
goldFile.close()
