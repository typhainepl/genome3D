package clustering;

#######################################################################################
# @author N. Nadzirin, T. Paysan-Lafosse
# @brief This script generates clusters based on superfamilies mapping between SCOP and CATH
#######################################################################################

use strict;
use warnings;
use DBI;

sub clustering{
	my ($pdbe_dbh,$node_mapping_db,$cluster_db) = @_;

	#-------------Start: Segment_scop---------#
	my $cluster_sth = $pdbe_dbh->prepare("select * from $node_mapping_db");

	$cluster_sth->execute();

	#----- made-up cluster 1---------#
	my (%cluster, %status, %final_cluster, %size);


	#--------getting real clusters----------
	while ( my $row = $cluster_sth->fetchrow_hashref ) {
		my $Cathnode = $row->{CATH_DOM};
		my $Scopnode = $row->{SCOP_DOM};
		my $avg_cath = $row->{AVG_PC_COV_OF_CATH_DOMAINS};
		my $avg_scop = $row->{AVG_PC_COV_OF_SCOP_DOMAINS};
		my $pc_CathNode_MappedThis_OverMapped = $row->{PC_CATH_IN_SCOP_IN_MAPPED_SCOP};
		my $pc_ScopNode_MappedThis_OverMapped = $row->{PC_SCOP_IN_CATH_IN_MAPPED_CATH};

		if ($avg_cath<=25 && $avg_scop<=25) {}
		elsif ($pc_CathNode_MappedThis_OverMapped<=25 && $pc_ScopNode_MappedThis_OverMapped<=25) {}
		else {
			push (@{$cluster{$Cathnode}},$Scopnode);
			push (@{$cluster{$Scopnode}},$Cathnode);
		}
	}


	#----- made-up status -----------#
	foreach my $keys (keys %cluster) {
		$status{$keys} = "no";
	}
	#--------------------------------#


	# accessing cluster

	my $super_parent;
	foreach $super_parent (keys %cluster) {

		if ($status{$super_parent} eq "no") {
			#--------------- Clustering in process $super_parent ---------------;
			my $previous_element_parent;
			foreach my $element_parent (@{$cluster{$super_parent}}) {
				if ($status{$element_parent} eq "no") {
					foreach my $element_child (@{$cluster{$element_parent}}) {
						if (!grep(/^$element_child$/,@{$cluster{$super_parent}})){
							push (@{$cluster{$super_parent}},$element_child);
						}
					}
					$status{$element_parent} = "yes";
				}
			}

			#--------------- AFTER clustering $super_parent ------------;
			my @array;
			foreach my $element_parent (@{$cluster{$super_parent}}) {
				push (@array, $element_parent);
			}
			$final_cluster{$super_parent} = [@array];
			$size{$super_parent} = @array;

			undef @array;
		}
	}


	print "clustering\n";

	my $counter=0;
	foreach my $final_parent (sort { $size{$b} <=> $size{$a} } keys %size) {
		my $parent='';
		my $nodes='';
		foreach my $element (sort @{$final_cluster{$final_parent}}) {
			if($counter eq 0){
				$parent = $element;
				$counter=1;
				# print $parent."\n";
			}
			$nodes.=$element." ";

		}
		$nodes =~ s/\s+$//;
		insertCluster($pdbe_dbh,$parent,$nodes,$cluster_db);

		$counter=0;
	}
}

sub insertCluster{
	my ($pdbe_dbh, $parent, $nodes, $cluster_db) = @_;

	my $request = $pdbe_dbh->prepare("insert into $cluster_db (cluster_node, nodes) values ('$parent', '$nodes')");
	$request->execute() or die "Failed to insert data into CLUSTER table\n";
}



1;
