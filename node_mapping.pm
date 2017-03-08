package node_mapping;
 
#######################################################################################
# @author N. Nadzirin, T. Paysan-Lafosse
# @brief
# This script generates all the columns for PDBe_all_node_mapping
# Needs: stats for all SF (unmapped & mapped) from segment table with SF info
# Needs: stats for all mapped SF from pdbe_all_domain_mapping
#######################################################################################

use strict;
use warnings; 
use DBI;
 
sub nodeMapping{
	my ($pdbe_dbh, $segment_scop_db, $segment_cath_db, $domain_mapping_db, $node_mapping_db) = @_;

	# Gather data from subroutines
	# Note: scop_all & cath_all subroutines connects to individual segment tables, gather both MAPPED & UNMAPPED data
	#	e.g. NoOfScopDomainAll contains:
	#	No of domains under superfamily '1.1.1.10' in sifts_xef_residue
	# mapped subroutine reads the mapped table (pdbe_all_dom_map)
	#	e.g. NoOfDomainMapped is:
	#	No. of domains under superfamily '1.1.1.10 that is PRESENT in the domain mapping table
	#	i.e. no. of domains under that SF that matches to ANY scop domain at all
	my (%NoOfScopDomainAll, %NoOfScopOrdinalAll, %SeqLengthScopAll, %AvgLengthScopAll);
	my (%NoOfCathDomainAll, %NoOfCathOrdinalAll, %SeqLengthCathAll, %AvgLengthCathAll);
	my (%NoOfDomainMapped, %NoOfOrdinalMapped, %SeqLengthMapped, %AvgLengthMapped);

	my @DomOrdLenAvgScopAll = cathScopAll($segment_scop_db,$pdbe_dbh);
	%NoOfScopDomainAll= %{ $DomOrdLenAvgScopAll[0] };
	%NoOfScopOrdinalAll= %{ $DomOrdLenAvgScopAll[1] };
	%SeqLengthScopAll = %{ $DomOrdLenAvgScopAll[2] };
	%AvgLengthScopAll = %{ $DomOrdLenAvgScopAll[3] };

	my @DomOrdLenAvgCathAll = cathScopAll($segment_cath_db,$pdbe_dbh);
	%NoOfCathDomainAll= %{ $DomOrdLenAvgCathAll[0] };
	%NoOfCathOrdinalAll= %{ $DomOrdLenAvgCathAll[1] };
	%SeqLengthCathAll = %{ $DomOrdLenAvgCathAll[2] };
	%AvgLengthCathAll = %{ $DomOrdLenAvgCathAll[3] };

	my @DomOrdLenAvgMapped = mapped_any($domain_mapping_db,$pdbe_dbh);
	%NoOfDomainMapped= %{ $DomOrdLenAvgMapped[0] };
	%NoOfOrdinalMapped= %{ $DomOrdLenAvgMapped[1] };
	%SeqLengthMapped = %{ $DomOrdLenAvgMapped[2] };
	%AvgLengthMapped = %{ $DomOrdLenAvgMapped[3] };


	#-----------------------main---------------------------------

	my $mapped_together_sth = $pdbe_dbh->prepare("select * from $domain_mapping_db");
	$mapped_together_sth->execute();

	my ($hrefMappedTogether, $CathDom_Ordinal, $ScopDom_Ordinal, $ScopSuperfamily, %seen);

	while ( my $mapped_together_row = $mapped_together_sth->fetchrow_hashref ) {
		
		# if the percentage of mapping domain is less than 25, don't take it into account 
		my $pc_Small = $mapped_together_row->{PC_SMALLER};
		if ($pc_Small < 25) {next;}

	  	my $CathDomain = $mapped_together_row->{CATH_DOMAIN};
		my $CathSuperfamily = $mapped_together_row->{CATHCODE};
		my $CathOrdinal = $mapped_together_row->{CATH_ORDINAL};
		my $CathLength = $mapped_together_row->{CATH_LENGTH};
		my $pcCath = $mapped_together_row->{PC_CATH_DOMAIN};
		$CathDom_Ordinal = $CathDomain."-".$CathOrdinal;

		my $ScopDomain = $mapped_together_row->{SCOP_DOMAIN};
		my $ScopFamily = $mapped_together_row->{SCCS};
		if ($ScopFamily =~ /(.\.\d+\.\d+)\./) {$ScopSuperfamily = $1;}

		# scop superfamilies starting with h, i, j or k are not real superfamilies => ignore them
		if ($ScopSuperfamily =~ /^h|i|j|k/) {next;}

		my $ScopOrdinal = $mapped_together_row->{SCOP_ORDINAL};
		my $ScopLength = $mapped_together_row->{SCOP_LENGTH};
		my $pcScop = $mapped_together_row->{PC_SCOP_DOMAIN};
		$ScopDom_Ordinal = $ScopDomain."-".$ScopOrdinal;

		my $matched_SF = $CathSuperfamily.";".$ScopSuperfamily;
		my $matched_DomOrd = $CathDom_Ordinal.";".$ScopDom_Ordinal;
		my $matched_PC = $pcCath.";".$pcScop;
		
		$hrefMappedTogether->{ $matched_SF }->{ $matched_DomOrd } = $matched_PC;
	}

	my $counter_CathDom = 0;
	my $counter_ScopDom = 0;
	my $counter_CathDomOrd = 0;
	my $counter_ScopDomOrd = 0;
	my $pcCath_count = 0;
	my $pcScop_count = 0;

	my (%NoOfCathDomainMappedThis,%NoOfScopDomainMappedThis,%Equiv_60,%Equiv_80);
	my (%AvgPC_Cath,%AvgPC_Scop,%MinPC_Cath,%MaxPC_Cath,%MinPC_Scop,%MaxPC_Scop);
	my (%pc_CathNode_MappedAny,%pc_ScopNode_MappedAny, %pc_CathNode_MappedThis,%pc_ScopNode_MappedThis);
	my (%pc_CathNode_MappedThis_OverMapped, %pc_ScopNode_MappedThis_OverMapped);
	my (%EquivScore_Cath, %EquivScore_Scop);

	for my $k1 ( sort keys %$hrefMappedTogether ) {

		my ($CathSuperfamily, $ScopSuperfamily) = split(/;/,$k1);

		my ($pcCath, $pcScop, $min_pcCath, $max_pcCath, $min_pcScop, $max_pcScop);
		my $counter60 = 0; my $counter80 = 0;

	    for my $k2 ( keys %{$hrefMappedTogether->{ $k1 }} ) {

			my ($CathDomOrd,$ScopDomOrd) = split(/;/,$k2);
			my ($CathDom) = split(/-/,$CathDomOrd);
			my ($ScopDom) = split(/-/,$ScopDomOrd);


			if (!defined $pcCath) {$min_pcCath = 999; $max_pcCath=0;}
			if (!defined $pcScop) {$min_pcScop = 999; $max_pcScop=0;}

			($pcCath,$pcScop) = split(/;/,$hrefMappedTogether->{ $k1 }{ $k2 });

			my $DomainCombined = $CathDom.$ScopDom;
			if (!defined $seen{$DomainCombined}) {
				if ($pcCath > 60 && $pcScop > 60) {$counter60++;}
				if ($pcCath > 80 && $pcScop > 80) {$counter80++;}

				$pcCath_count = $pcCath_count + $pcCath;
				$pcScop_count = $pcScop_count + $pcScop;

				$seen{$DomainCombined} = "seen";
			}

			if ($pcCath < $min_pcCath) {$min_pcCath = $pcCath;}
			if ($pcCath > $max_pcCath) {$max_pcCath = $pcCath;}
			if ($pcScop < $min_pcScop) {$min_pcScop = $pcScop;}
			if ($pcScop > $max_pcScop) {$max_pcScop = $pcScop;}

			if (!defined $seen{$CathDom}) {$counter_CathDom++; $seen{$CathDom} = "seen";}
			if (!defined $seen{$ScopDom}) {$counter_ScopDom++; $seen{$ScopDom} = "seen";}
		}


		my $pc_CathNode_MappedAny = ($NoOfDomainMapped{$CathSuperfamily}/$NoOfCathDomainAll{$CathSuperfamily})*100;
		my $pc_ScopNode_MappedAny = ($NoOfDomainMapped{$ScopSuperfamily}/$NoOfScopDomainAll{$ScopSuperfamily})*100;

		my $pc_CathNode_MappedThis = ($counter_CathDom/$NoOfCathDomainAll{$CathSuperfamily})*100;
		my $pc_ScopNode_MappedThis = ($counter_ScopDom/$NoOfScopDomainAll{$ScopSuperfamily})*100;

		my $pc_CathNode_MappedThis_OverMapped = ($counter_CathDom/$NoOfDomainMapped{$CathSuperfamily})*100;
		my $pc_ScopNode_MappedThis_OverMapped = ($counter_ScopDom/$NoOfDomainMapped{$ScopSuperfamily})*100;


		#---------- gather all data ----------#
		$NoOfCathDomainMappedThis{$k1} = $counter_CathDom;
		$NoOfScopDomainMappedThis{$k1} = $counter_ScopDom;
		$Equiv_60{$k1} = $counter60;
		$Equiv_80{$k1} = $counter80;
		$AvgPC_Cath{$k1} = $pcCath_count/$counter_CathDom;
		$AvgPC_Scop{$k1} = $pcScop_count/$counter_ScopDom;
		$MinPC_Cath{$k1} = $min_pcCath; $MinPC_Scop{$k1} = $min_pcScop;
		$MaxPC_Cath{$k1} = $max_pcCath; $MaxPC_Scop{$k1} = $max_pcScop; 
		$pc_CathNode_MappedAny{$k1} =  $pc_CathNode_MappedAny;
		$pc_ScopNode_MappedAny{$k1} =  $pc_ScopNode_MappedAny;
		$pc_CathNode_MappedThis{$k1} = $pc_CathNode_MappedThis;
		$pc_ScopNode_MappedThis{$k1} = $pc_ScopNode_MappedThis;
		$pc_CathNode_MappedThis_OverMapped{$k1} = $pc_CathNode_MappedThis_OverMapped;
		$pc_ScopNode_MappedThis_OverMapped{$k1} = $pc_ScopNode_MappedThis_OverMapped;
		$EquivScore_Cath{$k1} = $pc_CathNode_MappedThis_OverMapped{$k1}*$AvgPC_Cath{$k1};
		$EquivScore_Scop{$k1} = $pc_ScopNode_MappedThis_OverMapped{$k1}*$AvgPC_Scop{$k1};
		#---------- end: gather data ----------#

		undef %seen;
		$counter_CathDom = 0;
		$counter_ScopDom = 0;
		$counter_CathDomOrd = 0;
		$counter_ScopDomOrd = 0;
		$pcCath_count = 0;
		$pcScop_count = 0;
	}

	#-----equivalence---------#
	my (%EquivMax);
	my (%Max);
	my (%MaxArg);
	foreach my $k1 (sort keys %pc_CathNode_MappedThis) { 

		my ($CathNode,$ScopNode) = split(/;/,$k1);

		if ($k1 =~ /$CathNode/ || $k1 =~ /$ScopNode/ ) {
			if (!defined $EquivMax{$CathNode}) {
				$Max{$CathNode} = $EquivScore_Cath{$k1};
				$EquivMax{$CathNode} = $k1;
			}
			else {
				if ($EquivScore_Cath{$k1} > $Max{$CathNode}) {
					$Max{$CathNode} = $EquivScore_Cath{$k1};
					$EquivMax{$CathNode} = $k1;
				}
			}

			if (!defined $EquivMax{$ScopNode}) {
				$Max{$ScopNode} = $EquivScore_Scop{$k1};
				$EquivMax{$ScopNode} = $k1;
			}
			else {
				if ($EquivScore_Scop{$k1} > $Max{$ScopNode}) {
					$Max{$ScopNode} = $EquivScore_Scop{$k1};
					$EquivMax{$ScopNode} = $k1;
				}
			}
	 	}
	}

	#-----equivalence---------#

	#get data from the table just created and insertion in PDBE_ALL_DOMAIN_MAPPING_NEW
	print "insert data in the $node_mapping_db table\n";

	#insert into PDBE_ALL_DOMAIN_MAPPING request
	my $insert_request = <<"SQL";
INSERT INTO $node_mapping_db (
	cath_dom,
	scop_dom,
	ssf,
	average_cath_length,
	average_scop_length,
	num_cath_node_domains,
	num_scop_node_domains ,
	num_cath_node_domains_in_scop,
	num_scop_node_domains_in_cath,
	cath_dom_in_mapped_scop_node,
	scop_dom_in_mapped_cath_node,
	num_60_pc_equivs,
	num_80_pc_equivs,
	avg_pc_cov_of_cath_domains,
	avg_pc_cov_of_scop_domains,
	min_pc_cov_of_cath_domains,
	min_pc_cov_of_scop_domains,
	max_pc_cov_of_cath_domains,
	max_pc_cov_of_scop_domains,
	pc_cath_domains_that_in_scop,
	pc_scop_domains_that_in_cath,
	pc_cathdom_in_mapped_scop_node,
	pc_scopdom_in_mapped_cath_node,
	pc_cath_in_scop_in_mapped_scop,
	pc_scop_in_cath_in_mapped_cath,
	is_most_equiv_scopnode_of_cath,
	is_most_equiv_cathnode_of_scop,
	are_mutually_most_equiv_nodes,
	mutual_equivalence_medal
	) 
	values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
SQL

	my $sth_insert = $pdbe_dbh->prepare($insert_request) or die "ERR prepare insertion\n";

	for my $k1 ( sort keys %$hrefMappedTogether ) {

		my ($CathSuperfamily, $ScopSuperfamily) = split(/;/,$k1);

		my $scop_superfamily_id = get_superfamily_id($pdbe_dbh,$ScopSuperfamily,$domain_mapping_db);

		my ($equivScopNodeCath,$equivCathNodeScop,$mutual,$medal_range);
		if ($EquivMax{$CathSuperfamily} eq $k1) { $equivScopNodeCath = "t";	}
		else { $equivScopNodeCath = "f"; }

		if ($EquivMax{$ScopSuperfamily} eq $k1) { $equivCathNodeScop = "t";	}
		else { $equivCathNodeScop = "f"; }

		if ($EquivMax{$CathSuperfamily} eq $k1 && $EquivMax{$ScopSuperfamily} eq $k1) {
			$mutual = "t";

			my $medal = medal($AvgPC_Cath{$k1},$AvgPC_Scop{$k1},$pc_CathNode_MappedThis_OverMapped{$k1},$pc_ScopNode_MappedThis_OverMapped{$k1},$MinPC_Cath{$k1},$MinPC_Scop{$k1});
			if (defined $medal) { $medal_range = 	$medal;	}
		}
		else {	$mutual = "f";	}

		#insert data in the table
		$sth_insert->execute(
			$CathSuperfamily,
			$ScopSuperfamily,
			$scop_superfamily_id,
			$AvgLengthCathAll{$CathSuperfamily},
			$AvgLengthScopAll{$ScopSuperfamily},
			$NoOfCathDomainAll{$CathSuperfamily},
			$NoOfScopDomainAll{$ScopSuperfamily},
			$NoOfDomainMapped{$CathSuperfamily},
			$NoOfDomainMapped{$ScopSuperfamily},
			$NoOfCathDomainMappedThis{$k1},
			$NoOfScopDomainMappedThis{$k1},
			$Equiv_60{$k1},
			$Equiv_80{$k1},
			$AvgPC_Cath{$k1},
			$AvgPC_Scop{$k1},
			$MinPC_Cath{$k1},
			$MinPC_Scop{$k1},
			$MaxPC_Cath{$k1},
			$MaxPC_Scop{$k1},
			$pc_CathNode_MappedAny{$k1},
			$pc_ScopNode_MappedAny{$k1},
			$pc_CathNode_MappedThis{$k1},
			$pc_ScopNode_MappedThis{$k1},
			$pc_CathNode_MappedThis_OverMapped{$k1},
			$pc_ScopNode_MappedThis_OverMapped{$k1},
			$equivScopNodeCath,
			$equivCathNodeScop,
			$mutual,
			$medal_range
		);
 	}
 }

#----------------------endmain--------------------------------

sub get_superfamily_id{
	#return the scop superfamily id corresponding to the SCCS
	my ($pdbe_dbh, $scop, $domain_mapping_db)=@_;

	my $request = $pdbe_dbh->prepare("select ssf from $domain_mapping_db where sccs like '$scop%' ");
	$request->execute() or die;

	while (my $all_row = $request->fetchrow_hashref){
		return $all_row->{SSF};
<<<<<<< HEAD
=======
		# my $sccs = $all_row->{SCCS};
		# my $superfamily = $all_row->{SUPERFAMILY_ID};

		# if ($sccs =~ /(.\.\d+\.\d+)\./) {$sccs = $1;}
		# # print $sccs."\t";
		
		# if($sccs eq $scop){
		# 	return $superfamily;
		# }
		
>>>>>>> branch 'test' of https://github.com/typhainepl/genome3D.git
	}
	return 0;

}

# Determine the medal score for superfamilies mapped
sub medal {
# BRONZE (c):
# 1) mutual equiv
# 2) Avg_pc_cov_cath || Avg_pc_cov_scop || PC_CATH_IN_SCOP_IN_MAPPED_SCOP || PC_SCOPDOM_IN_MAPPED_CATH_NODE < 80

# SILVER (b):
# 1) mutual equiv
# 2) Avg_pc_cov_cath && Avg_pac_cov_scop > 80
# 3) PC_CATH_IN_SCOP_IN_MAPPED_SCOP && PC_SCOP_IN_CATH_IN_MAPPED_CATH > 80
# 4) MIN_PC_COV_OF_CATH_DOMAINS || MIN_PC_COV_OF_SCOP_DOMAINS < 80

# GOLD (a)
# 1) mutual equiv
# 2) Avg_pc_cov_cath && Avg_pac_cov_scop > 80
# 3) PC_CATH_IN_SCOP_IN_MAPPED_SCOP && PC_SCOPDOM_IN_MAPPED_CATH_NODE > 80
# 4) MIN_PC_COV_OF_CATH_DOMAINS || MIN_PC_COV_OF_SCOP_DOMAINS > 80

  my $medal;
  my ($AvgCath, $AvgScop, $CathPC_OverMapped, $ScopPC_OverMapped, $MinPC_Cath, $MinPC_Scop) = @_;
  if ($AvgCath<80 || $AvgScop<80 || $CathPC_OverMapped<80 || $ScopPC_OverMapped<80) { $medal = "c"; }
  elsif ($MinPC_Cath<80 || $MinPC_Scop<80) { $medal="b"; }
  else { $medal="a"; }
  return $medal;
}


# get data from SEGMENT_CATH or SEGMENT_SCOP tables
sub cathScopAll{
	my ($segment_db,$pdbe_dbh) = @_;

	#initialize variables
	my (%NoOfDomainAll, %NoOfOrdinalAll, %SeqLengthAll, %AvgLengthAll, %seen);
	my $hashrefAll;

	my $seq_length = 0;
	my $counter_DomainOrd = 0;
	my $counter_Domain = 0;

	my $all_sth = $pdbe_dbh->prepare("select * from $segment_db");
	$all_sth->execute();

	while (my $all_row = $all_sth->fetchrow_hashref){
		my ($domain,$superfamily);

		if ($segment_db =~ /CATH/){
			$domain = $all_row->{DOMAIN};
			$superfamily = $all_row->{CATHCODE};
		}
		else{
			$domain = $all_row->{DOMAIN};
			my $family = $all_row->{SCCS};
			if ($family =~ /(.\.\d+\.\d+)\./) {$superfamily = $1;}
		}

		my $ordinal = $all_row->{ORDINAL};
		my $entry = $all_row->{ENTRY_ID};
		my $SiftsLength = $all_row->{LENGTH};

		if (!defined $superfamily){print "pb superfamily not defined\n";}
		
		my $Dom_Ordinal = $domain.";".$ordinal;
	
		$hashrefAll->{ $superfamily }->{ $Dom_Ordinal } = $SiftsLength;
	}
	

	# count domains, ordinals, average length
	for my $k1 ( sort keys %$hashrefAll ) {

		for my $k2 ( keys %{$hashrefAll->{ $k1 }} ) {
			$counter_DomainOrd ++;

			$seq_length = $seq_length + $hashrefAll->{ $k1 }{ $k2 };

			my @DomOrd = split (/;/,$k2);
			if (!defined $seen{$DomOrd[0]}) {$counter_Domain++; $seen{$DomOrd[0]} = "seen";}

			undef @DomOrd;
		}
		
		$NoOfDomainAll{$k1}= $counter_Domain;
		$NoOfOrdinalAll{$k1}= $counter_DomainOrd;
		$SeqLengthAll{$k1} = $seq_length;
		$AvgLengthAll{$k1} = $seq_length/$counter_Domain;

		$seq_length = 0;
		$counter_Domain = 0;
		$counter_DomainOrd = 0;
	}
	# NOTES:
	# Superfamily: keys %$hashrefAll
	# Cath_domain: keys %{$hashrefAll->{ $k1 }}
	# Seq_length:  $hashrefAll->{ $k1 }{ $k2 }
	
	return (\%NoOfDomainAll, \%NoOfOrdinalAll, \%SeqLengthAll, \%AvgLengthAll); 
}


sub mapped_any {
	my ($domain_mapping_db,$pdbe_dbh) = @_;

	my $mapped_sth = $pdbe_dbh->prepare("select * from $domain_mapping_db");
	$mapped_sth->execute();

	my ($hrefAllMapped, $CathDom_Ordinal, $ScopDom_Ordinal, $ScopSuperfamily, %seen);
	my (%NoOfDomainMapped,%NoOfOrdinalsMapped,%SeqLengthMapped,%AvgLengthMapped);

	# iterate through mapped table 
	while ( my $mapped_row = $mapped_sth->fetchrow_hashref ) {
		my $pc_Small = $mapped_row->{PC_SMALLER};
		if ($pc_Small < 25) {next;}
		my $CathDomain = $mapped_row->{CATH_DOMAIN};
		my $CathSuperfamily = $mapped_row->{CATHCODE};
		my $CathOrdinal = $mapped_row->{CATH_ORDINAL};
		my $CathLength = $mapped_row->{CATH_LENGTH};

		$CathDom_Ordinal = $CathDomain.";".$CathOrdinal;
		$hrefAllMapped->{"Cath"}->{ $CathSuperfamily }->{ $CathDom_Ordinal }    = $CathLength;

		my $ScopDomain = $mapped_row->{SCOP_DOMAIN};
		my $ScopFamily = $mapped_row->{SCCS};
		if ($ScopFamily =~ /(.\.\d+\.\d+)\./) {$ScopSuperfamily = $1;}
		my $ScopOrdinal = $mapped_row->{SCOP_ORDINAL};
		my $ScopLength = $mapped_row->{SCOP_LENGTH};

		$ScopDom_Ordinal = $ScopDomain.";".$ScopOrdinal;
		$hrefAllMapped->{"Scop"}->{ $ScopSuperfamily }->{ $ScopDom_Ordinal }    = $ScopLength;
	}
	my $seq_length = 0;
	my $counter_DomainOrd = 0;
	my $counter_Domain = 0;

	# count domains, average length for scop & cath in mapped
	for my $k1 ( sort keys %$hrefAllMapped ) {

		for my $k2 ( keys %{$hrefAllMapped->{ $k1 }} ) {

			for my $k3 ( keys %{$hrefAllMapped->{ $k1 }{ $k2 }} ) {
				$counter_DomainOrd ++;
				$seq_length += $hrefAllMapped->{ $k1 }{ $k2 }{ $k3 };

				my @DomOrd = split (/;/,$k3);
				if (!defined $seen{$DomOrd[0]}) { $counter_Domain++; $seen{$DomOrd[0]} = "seen"; }
				undef @DomOrd;
			}

			$NoOfDomainMapped{$k2} = $counter_Domain;
			$NoOfOrdinalsMapped{$k2} = $counter_DomainOrd;
			$SeqLengthMapped{$k2} = $seq_length;
			$AvgLengthMapped{$k2} = $seq_length/$counter_Domain;
			$seq_length = 0;
			$counter_DomainOrd = 0;
			$counter_Domain = 0;
		}
	}
	# NOTES:
	# Superfamily: keys %$hrefAllMapped
	# Cath_domain: keys %{$hrefAllMapped->{ $k1 }}
	# Seq_length:  $hrefAllMapped->{ $k1 }{ $k2 }
	return (\%NoOfDomainMapped,\%NoOfOrdinalsMapped,\%SeqLengthMapped,\%AvgLengthMapped);
}

1;