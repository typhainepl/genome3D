package get_mda_blocks;
 
#######################################################################################
# @author T. Paysan-Lafosse
# For each cluster, this script determine different MDA blocks (arrangement between CATH and SCOP superfamilies)
# prints only blocks with at list one CATH and one SCOP superfamilies
#######################################################################################

use strict;
use warnings;
use DBI;
use Data::Dumper;
 
sub getMDABlocks{
	my ($pdbe_dbh, $directory, $representative, %db) = @_;

	print "determine MDA blocks\n";
	#initialize databases names
	my $segment_scop_db = $db{'SEGMENT_SCOP'};
	my $segment_cath_db = $db{'SEGMENT_CATH'};
	my $domain_mapping  = $db{'PDBE_ALL_DOMAIN_MAPPING'};
	my $cluster_db 		= $db{'CLUSTER'};
	my $block_chain_db	= $db{'BLOCK_CHAIN'};
	my $mda_blocks_db	= $db{'MDA_BLOCK'};
	my $cluster_block_db= $db{'CLUSTER_BLOCK'};
	my $block_uniprot_db= $db{'BLOCK_UNIPROT'};

	#---- preparing request ----#

	my $cluster_sth = $pdbe_dbh->prepare("SELECT * FROM $cluster_db order by length(nodes) desc");
	my $scop_sth = $pdbe_dbh->prepare("select * from $segment_scop_db");
	my $cath_sth = $pdbe_dbh->prepare("select * from $segment_cath_db");
	my $map_sth = $pdbe_dbh->prepare("select * from $domain_mapping");

	#---- end preparing request ----#

	# global from segment tables
	my (%region, %SF, %domain, %chain, %mappedRegion, %DomainLength);
	# global from mapping table
	my (%mapped_domain, %mapped_chainScop, %mapped_chainCath);

	
	#-------------Start: get data from segment_scop table ---------#
	$scop_sth->execute();

	while ( my $xref_row = $scop_sth->fetchrow_hashref ) {
		my $ScopID = $xref_row->{SCOP_ID};
		my $SiftsStart = $xref_row->{SIFTS_START};
		my $SiftsEnd = $xref_row->{SIFTS_END};
		my $SiftLength = $SiftsEnd - $SiftsStart;

		my $EntryID = $xref_row->{ENTRY_ID};
		my $ChainID = $xref_row->{AUTH_ASYM_ID};
		my $Ordinal = $xref_row->{ORDINAL};
		my $key = $EntryID.$ChainID;

		my $region = $key."::".$SiftsStart."-".$SiftsEnd;
		my $SCCS = $xref_row->{SCCS};
		my $ScopNode;
		if ($SCCS =~ /(.+\..+\..+)\..+/) {$ScopNode = $1;}
		
		my $MappedRegionKey = $ScopID.";".$Ordinal;
		$DomainLength{$MappedRegionKey} = $SiftLength;
		$mappedRegion{$MappedRegionKey} = $region;
		push (@{$region{$ScopID}}, $region);

		my $SFidentifier = $ScopID.";;".$SiftsStart."-".$SiftsEnd;
		$SF{$MappedRegionKey} = $ScopNode;
		
		#print $ScopID."\t".$ScopNode."\n";

		push (@{$domain{$key}},$MappedRegionKey);
		push (@{$chain{$ScopNode}},$key);
		
	}
	#-------------End: get data from segment_scop table ---------#
	
	#-------------Start: get data from segment_cath table ---------#
	
	$cath_sth->execute();

	while ( my $xref_row = $cath_sth->fetchrow_hashref ) {
		my $CathID = $xref_row->{CATH_DOMAIN};
		my $SiftsStart = $xref_row->{SIFTS_START};
		my $SiftsEnd = $xref_row->{SIFTS_END};
		my $SiftLength = $SiftsEnd - $SiftsStart;

		my $Ordinal = $xref_row->{ORDINAL};
		my ($EntryID,$ChainID);
		if ($CathID =~ /(....)(.).{2}/) {$EntryID = $1; $ChainID=$2;}
		my $key = $EntryID.$ChainID;
		my $region = $key."::".$SiftsStart."-".$SiftsEnd;
		my $CathNode = $xref_row->{CATHCODE};
		#print $CathID."\t".$CathNode."\n";
		my $MappedRegionKey = $CathID.";".$Ordinal;
		$mappedRegion{$MappedRegionKey} = $region;
		$DomainLength{$MappedRegionKey} = $SiftLength;
		push (@{$region{$CathID}}, $region);

		my $SFidentifier = $CathID.";;".$SiftsStart."-".$SiftsEnd;
		$SF{$MappedRegionKey} = $CathNode;
		push (@{$domain{$key}},$MappedRegionKey);
		push (@{$chain{$CathNode}},$key);
	}
	#-------------End: get data from segment_cath table ---------#

	#-------------Start: Get overlapping domain (with cutoff 50% over smaller domain) ---------#
	$map_sth->execute();

	while ( my $xref_row = $map_sth->fetchrow_hashref ) {
		my $CathID = $xref_row->{CATH_DOMAIN}; 
		my $CathOrdinal = $xref_row->{CATH_ORDINAL}; 
		my $ScopID = $xref_row->{SCOP_ID};
		my $ScopOrdinal = $xref_row->{SCOP_ORDINAL}; 
		my $PCSmaller = $xref_row->{PC_SMALLER};

		my $CathSeg = $CathID.";".$CathOrdinal;
		my $ScopSeg = $ScopID.";".$ScopOrdinal;

		# get region that was extracted segment tables
		my ($Ent_chaincath,$mappedRegionCath) = split (/::/,$mappedRegion{$CathSeg});
		my ($startCath,$endCath) = split (/-/,$mappedRegionCath);
		my ($Ent_chainscop,$mappedRegionScop) = split (/::/,$mappedRegion{$ScopSeg});
		my ($startScop,$endScop) = split (/-/,$mappedRegionScop);

		if ($PCSmaller > 50) {
			my @c;	$c[0] = $ScopSeg; $c[1] = $startScop; $c[2] = $endScop;
			push (@{$mapped_domain{$CathSeg}},[ @c ]);
			my @d;	$d[0] = $CathSeg; $d[1] = $startCath; $c[2] = $endCath;
			push (@{$mapped_domain{$ScopSeg}},[ @d ]);
			
			if ($CathID=~/(.{5})\d\d/) {
				my $ChainID = $1;
				my @a;	$a[0] = $CathSeg; $a[1] = $startCath; $a[2] = $endCath;
				push (@{$mapped_chainCath{$ChainID}},[ @a ]);
				my @b;	$b[0] = $ScopSeg; $b[1] = $startScop; $b[2] = $endScop;
				push (@{$mapped_chainScop{$ChainID}},[ @b ]);
			} 

		}
	}
	#------------------------End: Get overlapping domain (with cutoff 50% over smaller domain) ----------------#

	#--------------Start: Main Program-----------#

	my %rep = get_representative($representative);


	$cluster_sth->execute() or die "! Error: encountered an error when executing SQL statement:\n";

	# go through each cluster
	while ( my $cluster_row = $cluster_sth->fetchrow_hashref ) {

		#variables for each unique chain
		my $NoOfChain=0; 
		my %seen; 
		my $valuesToInsert;
		my @where;

		# get nodes
		my $cluster_node = $cluster_row->{CLUSTER_NODE};
		my @node = split (/\s+/,$cluster_row->{NODES});

		# print "\nCluster $cluster_node\n";
		# print "------------------\nNodes in cluster:\n";
		# foreach my $node (@node) {print $node."\t";}

		# get unique chains in cluster BASED ON node (two chains can repeat if belong to diff nodes in cluster)

		my @repeated_chain;
		foreach my $node (@node) {
			foreach my $chain (@{$chain{$node}}) {
				my $SFchain = $node."-".$chain;
				push (@repeated_chain, $SFchain);
			}
		}
		my @uniq_chain = uniq(@repeated_chain);

		#for each unique chain in the cluster
		foreach my $uniq_chain (@uniq_chain) {
			if ($rep{$uniq_chain}) {					# only process representative unique chain
				my ($node, $chain) = split (/-/,$uniq_chain);
				if (!$seen{$chain}) {				# get truly unique chain in a cluster
					$NoOfChain++;
					# print "\n";
					# print $chain."\t";

					# --------------------Start Printing Top Part Of Chain -----------------------# 

					# my %listscop;
					# my %listcath;
					my %listregscop;
					my %listregcath;
					my $listcathscopSF;

					#for each domain in the chain
					# foreach my $element_ord (@{$domain{$chain}}) {					
					# 	my ($element,$ord) = split (/;/,$element_ord);
					# 	if (!$seen{$element}) {
					# 		# print $element;								# 1. print domain name
					# 		my ($descriptor,$real_region);

					# 		#for each region in the domain, get the end of the region and the superfamily (will be used to make SF sequence concatenation)
					# 		foreach my $region (@{$region{$element}}) {		
					# 			my $end;
					# 			my $reg;
					# 			($descriptor,$real_region) = split (/::/,$region);
					# 			if ($element =~ /\./) {
					# 				if($region=~/(-?\d+[A-Z]?)-(-?\d+[A-Z]?)/){
					# 					$end = $2;
					# 					$reg = $region;
					# 				}
					# 				# print "($region) ";
					# 			}
					# 			else {
					# 				if($real_region=~/(-?\d+[A-Z]?)-(-?\d+[A-Z]?)/){
					# 					$end = $2;
					# 					$reg = $real_region;
					# 				}
					# 				# print "($real_region)";					# 2. print region
					# 			}  
					# 			if ($SF{$element_ord}=~/^[a-z]/){
					# 				$listscop{$end} = $SF{$element_ord};
					# 				$listregscop{$reg} = $SF{$element_ord};					
					# 			}	
					# 			else{
					# 				$listcath{$end}=$SF{$element_ord};
					# 				$listregcath{$reg}=$SF{$element_ord};
					# 			}
					# 		}
					# 		# print "[$SF{$element_ord}]  ";					# 3. print SF
							
					# 		if ($element !~ /\./) {
					# 			$seen{$element}="seen";
					# 		}
					# 	}
					# }
					if (defined @{$mapped_chainCath{$chain}}) {
						@{$mapped_chainCath{$chain}} = sort { $a->[1] <=> $b->[1] } @{$mapped_chainCath{$chain}};
					}

					# 2) @{$mapped_chainCath{$ChainID}}
					# e.g. @{$mapped_chainCath{1e8zA}} = (  1e8zA01_1, 2  
					#					1e8zA02_1, 215
					#					1e8zA03_1, 329  )
					# {$hash_node{$node} = "defined";}

					foreach my $arr_domord (@{$mapped_chainCath{$chain}}) {
						my @arr_domord = $arr_domord;
						my $domord = $arr_domord[0][0];
						my $start = $arr_domord[0][1];
						my $end = $arr_domord[0][2];
						my $reg = $start."-".$end;

						$listregcath{$reg}=$SF{$domord};
						# $listcath{$end}=$SF{$domord};
					}
					my @sortcath = sortCathScopV2(%listregcath);
					my $listcathSF = $sortcath[0];
					my $listcathpos = $sortcath[1];

					if (defined @{$mapped_chainScop{$chain}}) {
						@{$mapped_chainScop{$chain}} = sort { $a->[1] <=> $b->[1] } @{$mapped_chainScop{$chain}};
					}

					foreach my $arr_domord (@{$mapped_chainScop{$chain}}) {
						my @arr_domord = $arr_domord;
						my $domord = $arr_domord[0][0];
						my $start = $arr_domord[0][1];
						my $end = $arr_domord[0][2];
						my $reg = $start."-".$end;

						$listregscop{$reg} = $SF{$domord};
						# $listscop{$end} = $SF{$domord};
					}
					my @sortscop = sortCathScopV2(%listregscop);
					my $listscopSF = $sortscop[0];
					my $listscoppos = $sortscop[1];

					my $gold = "no";
					my $cpt_gold=0;
					foreach my $cath (keys %listregcath){
						if (grep (/^$cath$/, keys %listregscop)){
							$cpt_gold++;
							# $gold = "yes";
						}
					}

					if ($cpt_gold eq keys %listregcath and keys %listregcath > 0){
						$gold="yes";
					}
					#----- MDA blocks ----#


					# concatenate cath and scop domains
					$listcathscopSF = $listcathSF." ".$listscopSF;
					# print $listcathscop." $gold\n" if ($gold eq "yes");

					# delete blank space begin and end in case of undefined CATH/SCOP SF
					$listcathscopSF =~ s/\s+$//;
					$listcathscopSF =~ s/^\s+//;

					# get number of SF defined for CATH and SCOP
					my $sizeListCath = keys %listregcath;
					my $sizeListScop = keys %listregscop;

					# case undefined CATH or SCOP SF
					# my $missing="null";

					# if($sizeListCath eq 0){
					# 	$missing = "Cath";
					# }
					# elsif($sizeListScop eq 0){
					# 	$missing = "Scop";
					# }

					if ($listcathscopSF ne ''){
						#insert blocks into MDA_BLOCK table and add info for missing CATH or SCOP mapping
						$valuesToInsert = "$listcathscopSF,$listcathpos,$listscoppos";
						@where = ('block','positionCath','positionScop');
						insertData($pdbe_dbh,$valuesToInsert,$mda_blocks_db,@where);

						#insert couples block/chainid into BLOCK_CHAIN table
						$valuesToInsert = "$listcathscopSF,$chain";
						@where = ('block','chain_id');
						insertData($pdbe_dbh,$valuesToInsert,$block_chain_db,@where);

						#insert couples cluster_node/block into CLUSTER_BLOCK table
						if(!$seen{$listcathscopSF}){
							my $percentage = "null";
							$valuesToInsert = "$cluster_node,$listcathscopSF,$gold,$percentage";
							@where = ('cluster_node','block','gold','percentage');
							insertData($pdbe_dbh,$valuesToInsert,$cluster_block_db,@where);
						}
						#get uniprot
						
						my $uniprotid = getUniprot($chain, $pdbe_dbh);
						$valuesToInsert = "$listcathscopSF,$uniprotid";
						@where = ('block','accession');
						insertData($pdbe_dbh,$valuesToInsert,$block_uniprot_db,@where);

						#----- End MDA blocks ----#
							
						# --------------------End Printing Top Part Of Chain -----------------------#

						
						$seen{$listcathscopSF} ='seen';		
					}				
					$seen{$chain} = 'seen';	
				}													
			} # REPRESENTATIVE  
		}

		# print "\nThis cluster has $NoOfChain unique chains.\n";	
		getUniprotPercentage($pdbe_dbh,$block_uniprot_db,$cluster_block_db,$mda_blocks_db,$cluster_node);
	}				
}

sub uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

# get representative list, put in hash %rep
sub get_representative {
	my ($representative) = @_;
	my @repr; 
	my %rep; 
	open REP, $representative;
	while (my $line = <REP>) { chomp ($line); push (@repr,$line)}
	foreach my $repr (@repr) {$rep{$repr} = "defined";}
	return %rep;
}

sub getUniprot{
	my ($chain,$pdbe_dbh) = @_;

	my $pdb = substr($chain,0,4);
	my $chain_num = substr($chain,-1);
	my $uniprot = "None";

	my $get_uniprot = $pdbe_dbh->prepare("select accession from sifts_xref_residue where entry_id=? and AUTH_ASYM_ID=? and accession is not null");
	$get_uniprot->execute($pdb,$chain_num);
	
	while (my $row = $get_uniprot->fetchrow_hashref) {
		$uniprot = $row->{ACCESSION};
	}	

	return $uniprot;
}

sub getUniprotPercentage{
	my ($pdbe_dbh,$block_uniprot_db,$cluster_block_db,$mda_blocks_db,$cluster) = @_;

	# get the total number of blocks in the cluster
	my $get_count_total_block_sth = $pdbe_dbh->prepare("select count(bu.accession) from $block_uniprot_db bu join $cluster_block_db cb using(block) join $mda_blocks_db using(block) where cluster_node=?");
	my $nbTotalBlock=0;

	$get_count_total_block_sth->execute($cluster) or die;
	while(my @temp = $get_count_total_block_sth->fetchrow_array){
		$nbTotalBlock = $temp[0];
	}

	#get the number of uniprot id by block
	my $get_uniprot_by_block = $pdbe_dbh->prepare("select bu.block, count(*) as NB_UNIPROT 
from $cluster_block_db cb
join $block_uniprot_db bu on cb.block=bu.block
join $mda_blocks_db mb on cb.block=mb.block
where cluster_node=?
group by bu.block");

	$get_uniprot_by_block->execute($cluster) or die;

	#update the uniprot percentage in cluster_block table
	my $update_block= $pdbe_dbh->prepare("update $cluster_block_db set percentage=? where cluster_node=? and block=?");

	while ( my $row = $get_uniprot_by_block->fetchrow_hashref ) {
		my $block = $row->{BLOCK};	
		my $uniprot = $row->{NB_UNIPROT};

		my $uniprotPercent = $uniprot/$nbTotalBlock * 100;

		$update_block->execute($uniprotPercent,$cluster,$block);

	}
}

sub getCoverage{
	my ($chain, $pdbe_dbh) = @_;
	my $pdb = substr($chain,0,4);
	my $chainid = substr($chain,-1);
	my $coverage = 0;

	#get the coverage percentage of the uniprot domain by the chain
	my $search_coverage = $pdbe_dbh->prepare("select coverage from coverage where ENTRY_ID=? and AUTH_ASYM_ID=?");
	$search_coverage->execute($pdb,$chainid);

	while (my $row = $search_coverage->fetchrow_hashref) {
		$coverage = sprintf ("%0.2f",$row->{COVERAGE})*100;
	}	

	return $coverage;
}

sub sortCathScop{
	my (%hashSF)= @_;
	my $sortlist="";

	foreach my $key (sort {$a <=> $b} keys %hashSF){
		$sortlist.=$hashSF{$key}." ";
	}
	$sortlist =~ s/\s+$//; 

	return $sortlist;
}

sub sortCathScopV2{
	my (%hashSF)= @_;
	my $sortSF="";
	my $sortpos="";
	my @toSort;

	foreach my $key (keys %hashSF){
		my @position = split('-',$key);
		my $start = $position[0];
		my $end = $position[1];
		push (@toSort,$end);
	}

	foreach my $pos (sort {$a <=> $b} @toSort){
		foreach my $key (keys %hashSF){
			if ($key =~/-$pos$/){
				$sortSF.=$hashSF{$key}." ";
				$sortpos.=$key." ";
			}
		}
	}
	$sortSF  =~ s/^\s+//;
	$sortSF  =~ s/\s+$//; 
	$sortpos =~ s/^\s+//;
	$sortpos =~ s/\s+$//; 

	my @sorted = ($sortSF,$sortpos);

	return @sorted;
}

sub printMDABlocks{
	my ($directory, $pdbe_dbh, %db) = @_;

	print "writting MDA blocks files\n";

	open MDABLOCKS, ">>", $directory."mda_blocks.list";
	open MDAINFO, ">>", $directory."mda_info.list";

	#initialize databases names
	my $cluster_db 		= $db{'CLUSTER'};
	my $block_chain_db	= $db{'BLOCK_CHAIN'};
	my $mda_blocks_db	= $db{'MDA_BLOCK'};
	my $cluster_block_db= $db{'CLUSTER_BLOCK'};

	#preparing request to get info for each block
	my $get_cluster_sth = $pdbe_dbh->prepare("select * from $cluster_db order by length(nodes) asc") or die;

	my $get_mda_block_sth = $pdbe_dbh->prepare("select * from $mda_blocks_db join $cluster_block_db using (block) where cluster_node=? order by percentage desc, block desc") or die;

	my $get_count_mda_block_sth = $pdbe_dbh->prepare("select count(*) from $mda_blocks_db join $cluster_block_db using (block) where cluster_node=?") or die;

	my $get_total_uniprotid_cluster = $pdbe_dbh->prepare("select count(distinct(accession)) from sifts_xref_residue sxr
join block_chain_new bc 
on substr(bc.chain_id,0,4)=sxr.entry_id and substr(bc.chain_id,5,5)=sxr.auth_asym_id
join cluster_block_new cb on cb.block=bc.block
where cluster_node=? and accession is not null") or die;

	my $get_chain_sth = $pdbe_dbh->prepare("select * from $block_chain_db where block=? order by chain_id") or die;


	#for each cluster
	$get_cluster_sth->execute() or die;
	
	while ( my $row = $get_cluster_sth->fetchrow_hashref ) {
		my $cluster_node = $row->{CLUSTER_NODE};
		my $nodes = $row->{NODES};

		print MDABLOCKS "Cluster $cluster_node\n\n";
		print MDABLOCKS "Nodes in cluster: ".$nodes."\n\n";

		print MDAINFO "Cluster $cluster_node\n\n";
		print MDAINFO "Nodes in cluster: ".$nodes."\n";
		

		# for each mda block
		$get_mda_block_sth->execute($cluster_node) or die;
		$get_count_mda_block_sth->execute($cluster_node) or die;
		$get_total_uniprotid_cluster->execute($cluster_node) or die;

		#count number of block found for this cluster
		my $blockcount = 0;
		while(my @temp = $get_count_mda_block_sth->fetchrow_array){
			$blockcount = $temp[0];
		}

		my $nbUniprotTotal = 0;
		while(my @temp = $get_total_uniprotid_cluster->fetchrow_array){
			$nbUniprotTotal = $temp[0];
		}

		print MDABLOCKS $blockcount;
		if ($blockcount<=1) {
			print MDABLOCKS " block found";
		}
		else{
			print MDABLOCKS " blocks found";
		}

		print MDABLOCKS "\n-------------------\n\n";
		print MDAINFO "\n-------------------\n\n";

		#for each block, get block sequence and different chains
		while ( my $row2 = $get_mda_block_sth->fetchrow_hashref ) {
			my $block = $row2->{BLOCK};
			my $missing = $row2->{MISSING} if ($row2->{MISSING});
			my $uniprotPercent;
			if ($row2->{PERCENTAGE}){ 
				$uniprotPercent = eval sprintf('%.2f',$row2->{PERCENTAGE});
			}

			my %uniprotList;

			print MDABLOCKS $block;
			print MDAINFO $block;

			if ($row2->{GOLD}){
				print MDABLOCKS "\n!!! GOLD BLOCK !!!";
			}

			if ($missing){
				print MDABLOCKS "\nNo corresponding ".$missing." superfamily defined";
			}
			
			#for each chain in the block, get uniprotid and coverage percentage of uniprot domain
			$get_chain_sth->execute($block);

			while ( my $row3 = $get_chain_sth->fetchrow_hashref ) {
				my $chainid = $row3->{CHAIN_ID};
				my $uniprotid = getUniprot($chainid,$pdbe_dbh);
				my $coverage = getCoverage($chainid,$pdbe_dbh);

				if(!$uniprotList{$uniprotid}{"number"}){
					$uniprotList{$uniprotid}{"number"} = 1;
				}
				else{
					$uniprotList{$uniprotid}{"number"} ++;
				}

				$uniprotList{$uniprotid}{"chain"}{$chainid} = $coverage;

			}
			my $nbUniprotBlock = scalar(keys (%uniprotList));

			print MDABLOCKS "\nnumber of chains: ".scalar($get_chain_sth->rows);

			print MDABLOCKS "\nnumber of uniprot IDs: ".$nbUniprotBlock;
			
			if($uniprotPercent){
				print MDABLOCKS "\npercentage of uniprot regarding the whole cluster (excluding no equivalent CATH/SCOP defined): ".$uniprotPercent;
			}	
			print MDABLOCKS "\nuniprot: ";

			
			foreach my $uniprotid (sort keys %uniprotList){
				#for each uniprot found in the block, print uniprotid, number of occurences in mda_block file
				print MDABLOCKS $uniprotid;
				print MDABLOCKS "(".$uniprotList{$uniprotid}{"number"}.") ";

				#for each uniprot found in the block, print uniprotid, chains and uniprot domain coverage corresponding
				print MDAINFO "\n".$uniprotid.": ";
				foreach my $chain (sort keys %{$uniprotList{$uniprotid}{"chain"}}){
					print MDAINFO $chain." ";
					print MDAINFO " (".$uniprotList{$uniprotid}{"chain"}{$chain}."%)\t";
				}
			}

			print MDABLOCKS "\n\n";
			print MDAINFO "\n\n";
		}


		print MDABLOCKS "******************************\n\n";
		print MDAINFO "******************************\n\n";

	}

	close MDABLOCKS;
	close MDAINFO;
}

sub insertData{
	# insert data into database
	my ($pdbe_dbh,$values,$table,@where) = @_;

	my @tab;

	my @valuesList=split(",",$values);
	my ($whereCondition,$valueQuote,$whereList);
	my @valuesToInsert;
	my $size = $#where;

	# ---- check if data already in the database ---- #
	for (my $cpt=0; $cpt<=$size; $cpt++){
		if(($where[$cpt] eq 'gold' and $valuesList[$cpt] ne 'no') or $where[$cpt] ne 'gold'){
			$whereCondition.=$where[$cpt];

			if($valuesList[$cpt] ne 'null'){
				$whereCondition.="=\'".$valuesList[$cpt]."\' ";

				$whereList.=$where[$cpt].",";

				push(@valuesToInsert,$valuesList[$cpt])

			}
			else{
				$whereCondition.=" is null ";
			}
			if($cpt<$size){
				$whereCondition.="and ";
			}
		}
	}
	$whereList =~ s/,+$//;

	my $request  = "select * from $table where $whereCondition";
	# print "request: ".$request."\n";

	my $get_data = $pdbe_dbh->prepare($request);
	$get_data->execute() or die;
	
	while (my @row = $get_data->fetchrow_array) {
		push(@tab, $row[0]);
	}	

	# ---- if no data found in the table, insert new row ---- #
	if($#tab < 0){
		my $insert = "insert into $table($whereList) values(". join(",", map "?", @valuesToInsert). ")";
		# print "insert: ".$insert."\n";

		my $insert_sth = $pdbe_dbh->prepare($insert) or die;
		$insert_sth->execute(@valuesToInsert) or die;
	}
}

1;			




