#!/usr/bin/env python

#######################################################################################
# @author T. Paysan-Lafosse
# For each cluster, this script get particular blocks (gold, one to many domains between cath and scop MDA blocks)
#######################################################################################

import urllib2
import os

import ConfigParser
import sys
import re
import search_unintegrated

dirname = os.path.dirname(__file__)
if not dirname:
    dirname = '.'

directoryToPrint = dirname +"/"
unintegrated_gold_blocks_file = directoryToPrint+"unintegrated_gold_new"
unintegrated_previous = directoryToPrint+"unintegrated_previous"

previous = open (unintegrated_previous,'r')
goldFile = open (unintegrated_gold_blocks_file,'r')

gold_new = []
gold_old = []

for row in goldFile:
	pattern = re.match("^\n$",row)
	new = row.strip(" \n")
	if not pattern:
		gold_new.append(new)

for row in previous:
	pattern = re.match("^\n$",row)
	new = row.strip(" \n")
	if not pattern:
		gold_old.append(new)
# print gold_old

for row in gold_new:
	# print row
	if row not in gold_old:
		print row


previous.close()
goldFile.close()
