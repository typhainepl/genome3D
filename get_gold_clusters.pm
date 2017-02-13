package get_gold_clusters;
 
#######################################################################################
# @author T. Paysan-Lafosse
# This script print blocks into gold.list file for gold pairs from the previous mapping rules
#######################################################################################

use strict;
use warnings;
 
use DBI;
use Data::Dumper;


sub get_gold_clusters{
	my ($pdbe_dbh, $blockFile, $goldFile, $node_mapping_db) = @_;

	open GOLDS, ">", $goldFile;

	my $goldpairs = $pdbe_dbh->prepare("select * from $node_mapping_db where MUTUAL_EQUIVALENCE_MEDAL='a'");
	$goldpairs->execute();

	my %pairs;

	print "Print equivalent blocks for gold pairs into $goldFile\n";

	while ( my $xref_row = $goldpairs->fetchrow_hashref ) {
		my $cath = $xref_row->{CATH_DOM};
		my $scop = $xref_row->{SCOP_DOM};
		my $find = "FALSE";

		open MDABLOCKS, $blockFile;

		while (my $line = <MDABLOCKS>) {
			# print $line;
			if ($line =~/^Nodes in cluster: (.\..+)/){
				my $cluster = $1;
				my @nodes = split (/\s+/,$cluster);

				if (grep( /^$cath$/, @nodes )  && grep( /^$scop$/, @nodes )){
					print GOLDS $line;
					$find="TRUE";
				}
			}
			elsif($find eq "TRUE"){
				print GOLDS $line;
			}
			if($line=~/\*/){
				$find="FALSE";
			}
		}
		close MDABLOCKS;
	}

	close GOLDS;

}

1;