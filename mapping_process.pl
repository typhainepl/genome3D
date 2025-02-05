#!/usr/bin/env perl

#######################################################################################
# @author T. Paysan-Lafosse
# @brief This script generates all the tables from the sifts_xref_residue table to end up clustering all the superfamilies from CATH and SCOP
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
use get_chop_homo;
use get_gold_clusters;

# connexion to the database
my $path="/nfs/msd/work2/typhaine/genome3D/";
my %config = do $path.'./config/config.pl';    
my $pdbe_dbh = DBI->connect("DBI:Oracle:".$config{db}, $config{user}, $config{password});

print "Mapping process SCOP started ".localtime()."\n";

#delete and rename existing tables
#print "drop tables\n";

my @tables = ('SEGMENT_CATH','SEGMENT_SCOP','SEGMENT_CATH_SCOP','DOMAIN_MAPPING','NODE_MAPPING','BLOCK_CHAIN','BLOCK_UNIPROT','CLUSTER_BLOCK','MDA_BLOCK','CLUSTER');

my %tables_new;

foreach my $t (@tables){
	if ($t !~ /ECOD/){
		my $drop = 'DROP TABLE '.$t.'_OLD';
		my $alter = 'ALTER TABLE '.$t.'_NEW rename to '.$t.'_OLD';
		$pdbe_dbh->do($drop) or die "Can't delete ".$t."_OLD table\n\n";
		$pdbe_dbh->do($alter) or die "Can't rename ".$t."_NEW table\n\n";
		$tables_new{$t}=$t.'_NEW';
	}
}

my $mdaDirectory = $path."MDA_results/CATH_4_1/";
my $blockFile = $mdaDirectory."mda_blocks.list";
my $blockInfo = $mdaDirectory."mda_info.list";
my $goldFile = $mdaDirectory."gold.list";
my $representative = $path."representative/representative_list";

#create tables
create_tables::createTables($pdbe_dbh,'scop',%tables_new);

#create segment tables
get_segment::getSegmentCath($pdbe_dbh,$tables_new{'SEGMENT_CATH'});
get_segment::getSegmentScop($pdbe_dbh,$tables_new{'SEGMENT_SCOP'});

get_segment::createCombinedSegmentSCOP($pdbe_dbh, $tables_new{'SEGMENT_SCOP'},$tables_new{'SEGMENT_CATH'}, $tables_new{'SEGMENT_CATH_SCOP'});

#calculate and insert data in domain mapping
domain_mapping::mapping($pdbe_dbh, $tables_new{'SEGMENT_SCOP'},$tables_new{'SEGMENT_CATH'}, $tables_new{'SEGMENT_CATH_SCOP'}, $tables_new{'DOMAIN_MAPPING'});

#node mapping
node_mapping::nodeMapping($pdbe_dbh,$tables_new{'SEGMENT_SCOP'},$tables_new{'SEGMENT_CATH'}, $tables_new{'DOMAIN_MAPPING'},$tables_new{'NODE_MAPPING'});

#clustering
clustering::clustering($pdbe_dbh,$tables_new{'NODE_MAPPING'},$tables_new{'CLUSTER'});

#get medal equivalence
#get_medals::getMedals($pdbe_dbh,$tables_new{'NODE_MAPPING'});

#get MDA blocks
get_mda_blocks::getMDABlocks($pdbe_dbh, $mdaDirectory, $representative, 'scop', %tables_new);

#print MDA blocks info into files
cleanDirectory($mdaDirectory);

get_mda_blocks::printMDABlocks($mdaDirectory, $pdbe_dbh, %tables_new);

#print other mda info (one instance, equivalent split, class4...)
get_chop_homo::getChopping($pdbe_dbh, $mdaDirectory, $representative, 'scop', %tables_new);

#print equivalent gold pairs cluster blocks
# get_gold_clusters::get_gold_clusters($pdbe_dbh,$blockFile,$goldFile, $tables_new{'NODE_MAPPING'});

my $runtime = time - $^T."\n";
printf("\nTotal running time: %02d:%02d:%02d\n\n", int($runtime / 3600), int(($runtime % 3600) / 60), int($runtime % 60),"\n");
printf("###############################\n\n");

sub cleanDirectory{
	my ($directory) = @_;
	rmtree($directory);
	print "directory clean\n";

	mkdir $directory;
}
