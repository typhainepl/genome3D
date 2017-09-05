#!/usr/bin/env perl

#######################################################################################
# @author T. Paysan-Lafosse
# @brief This script generates all the tables from the sifts_xref_residue table to end up clustering all the superfamilies from CATH and ECOD
#######################################################################################

use strict;
use warnings;

use DBI;
use File::Path;

use create_tables;
use get_segment;
use domain_mapping;
use node_mapping;
use clustering;
use get_medals;
use get_mda_blocks;
use get_mda_blocks;
use get_chop_homo;
use get_gold_clusters;

# information that we need to specify to connect to the database

my $path="/nfs/msd/work2/typhaine/genome3D/";  
my %config = do $path.'./config/config.pl';  
my $pdbe_dbh = DBI->connect("DBI:Oracle:".$config{db}, $config{user}, $config{password});

print "Mapping process ECOD started ".localtime()."\n";

#delete and rename existing tables
#print "drop tables\n";

my @tables = ('SEGMENT_CATH','SEGMENT_ECOD','SEGMENT_CATH_ECOD','DOMAIN_MAPPING','NODE_MAPPING','BLOCK_CHAIN','BLOCK_UNIPROT','CLUSTER_BLOCK','MDA_BLOCK','CLUSTER');

my %tables_new;

foreach my $t (@tables){
	
	if ($t ne 'SEGMENT_ECOD' && $t ne 'SEGMENT_CATH'){
		my $var_new;
		my $var_old;
		if ($t eq 'SEGMENT_CATH_ECOD'){
			$var_new = '_NEW';
			$var_old = '_OLD';
		}
		else{
			$var_new = '_ECOD_NEW';
			$var_old = '_ECOD_OLD';
		}
		my $drop = 'DROP TABLE '.$t.$var_old;
		my $alter = 'ALTER TABLE '.$t.$var_new.' rename to '.$t.$var_old;
		$pdbe_dbh->do($drop) or die "Can't delete ".$t.$var_old." table\n\n";
		$pdbe_dbh->do($alter) or die "Can't rename ".$t.$var_new." table\n\n";
	}

	if ($t !~ /ECOD/ && $t ne 'SEGMENT_CATH' && $t ne 'SEGMENT_ECOD'){
		$tables_new{$t}=$t.'_ECOD_NEW';
	}
	else{
		$tables_new{$t}=$t.'_NEW';
	}
}

my $mdaDirectory = $path."MDA_results/CATH_ECOD/";
my $blockFile = $mdaDirectory."mda_blocks.list";
my $blockInfo = $mdaDirectory."mda_info.list";
my $goldFile = $mdaDirectory."gold.list";
my $representative = $path."representative/representative_list";

#create tables
create_tables::createTables($pdbe_dbh,'ecod',%tables_new);

#create segment tables
#get_segment::getSegmentCath($pdbe_dbh,$tables_new{'SEGMENT_CATH'});
my $output = $path.'update_databases/ecod_update.py';
system($output) == 0 or die "Can't update ECOD\n";

get_segment::createCombinedSegmentECOD($pdbe_dbh, $tables_new{'SEGMENT_ECOD'},$tables_new{'SEGMENT_CATH'}, $tables_new{'SEGMENT_CATH_ECOD'});

#calculate and create domain mapping
domain_mapping::mapping($pdbe_dbh, $tables_new{'SEGMENT_ECOD'},$tables_new{'SEGMENT_CATH'}, $tables_new{'SEGMENT_CATH_ECOD'}, $tables_new{'DOMAIN_MAPPING'});

#node mapping
node_mapping::nodeMapping($pdbe_dbh,$tables_new{'SEGMENT_ECOD'},$tables_new{'SEGMENT_CATH'}, $tables_new{'DOMAIN_MAPPING'},$tables_new{'NODE_MAPPING'});
#
#clustering
clustering::clustering($pdbe_dbh,$tables_new{'NODE_MAPPING'},$tables_new{'CLUSTER'});

#get medal equivalence
#get_medals::getMedals($pdbe_dbh,$tables_new{'NODE_MAPPING'});

#get MDA blocks
get_mda_blocks::getMDABlocks($pdbe_dbh, $mdaDirectory, $representative, 'ecod', %tables_new);

#print MDA blocks info into files
cleanDirectory($mdaDirectory);

get_mda_blocks::printMDABlocks($mdaDirectory, $pdbe_dbh, %tables_new);

#print other mda info (one instance, equivalent split, class4...)
get_chop_homo::getChopping($pdbe_dbh,$mdaDirectory, $representative,'ecod', %tables_new);

#print equivalent gold pairs cluster blocks
#get_gold_clusters::get_gold_clusters($pdbe_dbh,$blockFile,$goldFile, $tables_new{'NODE_MAPPING'});

my $runtime = time - $^T."\n";
printf("\nTotal running time: %02d:%02d:%02d\n\n", int($runtime / 3600), int(($runtime % 3600) / 60), int($runtime % 60),"\n");
printf("###############################\n\n");

sub cleanDirectory{
	my ($directory) = @_;
	rmtree($directory);
	print "directory clean\n";

	mkdir $directory;
}