package create_tables;
 
#######################################################################################
# @author T. Paysan-Lafosse
# This script creates the tables used in the mapping process
#######################################################################################

use strict;
use warnings;
use DBI;

sub createTables{
	my ($pdbe_dbh,$value, %db) = @_;

	print "create tables\n";
	#initialize databases names
	my $segment_scop_db;
	my $combined_segment_db;
	my $scop_lengths_db;
	
	if ($value eq 'scop'){
		$segment_scop_db = $db{'SEGMENT_SCOP'};
		$scop_lengths_db = $db{'SCOP_LENGTHS'};
		$combined_segment_db = $db{'SEGMENT_CATH_SCOP'};
	}
	else{
		$scop_lengths_db = $db{'ECOD_LENGTHS'};
		$combined_segment_db = $db{'SEGMENT_CATH_ECOD'};
	}
	
	my $cath_lengths_db = $db{'CATH_LENGTHS'};
	my $segment_cath_db = $db{'SEGMENT_CATH'};
	my $domain_mapping_db  = $db{'DOMAIN_MAPPING'};
	my $node_mapping_db  = $db{'NODE_MAPPING'};
	my $cluster_db 		= $db{'CLUSTER'};
	my $block_chain_db	= $db{'BLOCK_CHAIN'};
	my $mda_blocks_db	= $db{'MDA_BLOCK'};
	my $cluster_block_db= $db{'CLUSTER_BLOCK'};
	my $block_uniprot_db= $db{'BLOCK_UNIPROT'};

	# ---- create tables ----
 	my $create_segment_cath = <<"SQL";
CREATE TABLE $segment_cath_db(
 	domain varchar(10),
 	ordinal number(38,0),
 	entry_id varchar(4),
 	auth_asym_id varchar(5),
 	"START" number(38,0),
 	"END" number(38,0), 
 	length number(38,0),
 	cathcode varchar(20)
 )
SQL
	
	my $create_cath_lengths = <<"SQL";
CREATE TABLE $cath_lengths_db(
	entry_id varchar(4),
 	auth_asym_id varchar(5),
 	cathcode varchar(20),
 	length number(38,0),
 	pc_overlap number(38,0)
)
SQL

	if ($value eq 'scop'){
		
		$pdbe_dbh->do($create_segment_cath) or die "Can't create $segment_cath_db table\n\n";
		$pdbe_dbh->do($create_cath_lengths) or die "Can't create $cath_lengths_db table\n\n";

		my $create_segment_scop = <<"SQL";
CREATE TABLE $segment_scop_db(
 	domain varchar(10),
 	ordinal number(38,0),
 	entry_id varchar(4),
 	auth_asym_id varchar(5),
 	"START" number(38,0),
 	"END" number(38,0),
 	length number(38,0),
 	sccs varchar(20),
 	SSF number(38,0)
	)
SQL
	
		$pdbe_dbh->do($create_segment_scop) or die "Can't create $segment_scop_db table\n\n";
		
			my $create_scop_lengths = <<"SQL";
CREATE TABLE $scop_lengths_db(
	entry_id varchar(4),
 	auth_asym_id varchar(5),
 	SSF number(38,0),
 	length number(38,0),
 	pc_overlap number(38,0)
)
SQL
	
		$pdbe_dbh->do($create_scop_lengths) or die "Can't create $scop_lengths_db table\n\n";

	}


my $create_segment_cath_scop = <<"SQL";
CREATE TABLE $combined_segment_db(
	cath_domain varchar(10),
	cath_ordinal number,
	scop_domain varchar(10),
	scop_ordinal number,
	entry_id varchar(4),
	auth_asym_id varchar(3),
	cath_start number,
	cath_end number,
	cath_length number,
	scop_start number,
	scop_end number,
	scop_length number,
	cathcode varchar(20),
	sccs varchar(20),
	ssf number
)
SQL
	$pdbe_dbh->do($create_segment_cath_scop) or die "Can't create $combined_segment_db table\n\n";

	my $create_domain_mapping = <<"SQL";
CREATE TABLE $domain_mapping_db( 
	entry_id varchar(4),
	auth_asym_id varchar(3),
 	cath_domain varchar(10),
 	scop_domain varchar(10),
 	cath_ordinal number,
 	scop_ordinal number,
 	cath_length number,
 	scop_length number,
 	overlap_length number,
 	pc_cath number,
 	pc_scop number,
 	pc_cath_domain number,
 	pc_scop_domain number,
 	pc_smaller number,
 	pc_bigger number,
 	cathcode varchar(20),
 	sccs varchar(20),
 	ssf number
)
SQL

	$pdbe_dbh->do($create_domain_mapping) or die "Can't create $domain_mapping_db\n";

	my $create_node_mapping = <<"SQL";
CREATE TABLE $node_mapping_db(
 	cath_dom varchar(50),
 	scop_dom varchar(50),
 	ssf number,
 	average_cath_length number,
 	average_scop_length number,
 	num_cath_node_domains number,
 	num_scop_node_domains number,
 	num_cath_node_domains_in_scop number,
 	num_scop_node_domains_in_cath number,
 	cath_dom_in_mapped_scop_node number,
 	scop_dom_in_mapped_cath_node number,
 	num_60_pc_equivs number,
 	num_80_pc_equivs number,
 	avg_pc_cov_of_cath_domains number,
 	avg_pc_cov_of_scop_domains number,
 	min_pc_cov_of_cath_domains number,
 	min_pc_cov_of_scop_domains number,
 	max_pc_cov_of_cath_domains number,
 	max_pc_cov_of_scop_domains number,
 	pc_cath_domains_that_in_scop number,
 	pc_scop_domains_that_in_cath number,
 	pc_cathdom_in_mapped_scop_node number,
 	pc_scopdom_in_mapped_cath_node number,
 	pc_cath_in_scop_in_mapped_scop number,
 	pc_scop_in_cath_in_mapped_cath number,
 	is_most_equiv_scopnode_of_cath varchar(1),
 	is_most_equiv_cathnode_of_scop varchar(1),
 	are_mutually_most_equiv_nodes varchar(1),
 	mutual_equivalence_medal varchar(1)
 	)
SQL

	$pdbe_dbh->do($create_node_mapping) or die "Can't create $node_mapping_db table\n\n";

 	my $create_cluster = <<"SQL";
CREATE TABLE $cluster_db (
 	cluster_node varchar(20) not null,
 	nodes CLOB,
 	PRIMARY KEY (cluster_node)
)
SQL

	$pdbe_dbh->do($create_cluster) or die "Can't create $cluster_db table\n\n";


	my $create_cluster_block = <<"SQL";
CREATE TABLE $cluster_block_db(
	cluster_node varchar(20) not null,
	block varchar(300) not null,
	percentage number,
	gold varchar(5),
	PRIMARY KEY (cluster_node, block),
	FOREIGN KEY (cluster_node) references $cluster_db(cluster_node)
)
SQL

	$pdbe_dbh->do($create_cluster_block) or die "Can't create $cluster_block_db table\n\n";

	my $create_mda_blocks = <<"SQL";
CREATE TABLE $mda_blocks_db (
	block varchar(300) not null,
	positionCath varchar(200) not null,
	positionScop varchar(200) not null,
	PRIMARY KEY(block, positionCath, positionScop)
)
SQL

	$pdbe_dbh->do($create_mda_blocks) or die "Can't create $mda_blocks_db table\n\n";

	my $create_block_uniprot = <<"SQL";
CREATE TABLE $block_uniprot_db(
	block varchar(300) not null,
	accession varchar(15) not null,
	PRIMARY KEY (block,accession)
)
SQL

	$pdbe_dbh->do($create_block_uniprot) or die "Can't create $block_uniprot_db table\n\n";


	my $create_block_chain = <<"SQL";
CREATE TABLE $block_chain_db(
	block varchar(300) not null,
	chain_id varchar(5) not null,
	PRIMARY KEY (block,chain_id)
)
SQL

	$pdbe_dbh->do($create_block_chain) or die "Can't create $block_chain_db table\n\n";

}

1;