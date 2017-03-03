package get_chop_homo;
 
#######################################################################################
# @author T. Paysan-Lafosse
# For each cluster, this script determine different MDA blocks (arrangement between CATH and SCOP superfamilies)
#######################################################################################

use strict;
use warnings;
use DBI;

sub getChopping{
	my ($pdbe_dbh, $directory, $representative, %db) = @_;

	my $segment_scop_db = $db{'SEGMENT_SCOP'};
	my $segment_cath_db = $db{'SEGMENT_CATH'};
	my $domain_mapping  = $db{'PDBE_ALL_DOMAIN_MAPPING'};
	my $cluster_db 		= $db{'CLUSTER'};

	# global from segment
	my (%region, %SF, %domain, %chain, %mappedRegion, %DomainLength);
	# global from mapping table
	my (%mapped_domain, %mapped_chainScop, %mapped_chainCath);

	#---- preparing request ----#

	my $cluster_sth = $pdbe_dbh->prepare("SELECT * FROM $cluster_db order by length(nodes) desc");
	my $scop_sth = $pdbe_dbh->prepare("select * from $segment_scop_db");
	my $cath_sth = $pdbe_dbh->prepare("select * from $segment_cath_db");
	my $map_sth = $pdbe_dbh->prepare("select * from $domain_mapping");

	#---- end preparing request ----#

	#-------------Start: Segment_scop---------#
	#Should probably be function:#
	#From segment get:
	# 1) @region{$ScopID}	; array					# to cater for disc.domain & multiple chain
	# e.g. $region{d1a0h.1} = (1a0hA::110-159 , 1a0hB::1-259)

	# 2) $SF{$ScopID-$start-$end} ; scalar
	# e.g. $SF{d10gsa1;;77-209} = a.45.1 

	# 3) @domain{$chainID}
	# e.g. $domain{10gsA} = (d10gsa1, d10gsa2);

	# 4) @chain{$ScopNode}
	# e.g. $chain{a.45.1} = (10gsA, 1b4aB, 1awcA)

	# 5) $mappedRegion{$MappedRegionKey} = $region;
	# e.g. $mappedRegion{d10gsa1_1} = 10gsA::77-209		# each ordinal, one region

	#-------------Start: Segment_scop---------#
	$scop_sth->execute();

	while ( my $xref_row = $scop_sth->fetchrow_hashref ) {
		my $ScopID = $xref_row->{DOMAIN};
		my $SiftsStart = $xref_row->{START};
		my $SiftsEnd = $xref_row->{END};
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
	#-------------End: Segment_scop---------#

	#-------------Start: Segment_cath---------#
	$cath_sth->execute();

	while ( my $xref_row = $cath_sth->fetchrow_hashref ) {
		my $CathID = $xref_row->{DOMAIN};
		my $SiftsStart = $xref_row->{START};
		my $SiftsEnd = $xref_row->{END};
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
	#-------------End: Segment_cath---------#

	#----------------------------Get overlapping domain (with cutoff 50% over smaller domain) ----------------#
	# 1) GET @{$mapped_domain{$CathSeg}
	# e.g. $mapped_domain{10gsA01_1} = (d10gsa1_1,d10gsa2_1)

	# 2) GET @{$mapped_chainCath{$ChainID}}
	# e.g. @{$mapped_chainCath{1e8zA}} = (  1e8zA01_1, 2  
	#					1e8zA02_1, 215
	#					1e8zA03_1, 329  )

	# 3) GET @{$mapped_chainScop{$ChainID}}
	# e.g. @{$mapped_chainCath{10gsA}} = (  d1e8za3_1, 2  
	#					d1e8za2_1, 215
	#					d1e8za1_1, 383  )

	$map_sth->execute();

	while ( my $xref_row = $map_sth->fetchrow_hashref ) {
		my $CathID = $xref_row->{CATH_DOMAIN}; 
		my $CathOrdinal = $xref_row->{CATH_ORDINAL}; 
		my $ScopID = $xref_row->{SCOP_DOMAIN};
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
			my @c;	$c[0] = $ScopSeg; $c[1] = $startScop;
			push (@{$mapped_domain{$CathSeg}},[ @c ]);
			my @d;	$d[0] = $CathSeg; $d[1] = $startCath;
			push (@{$mapped_domain{$ScopSeg}},[ @d ]);
			
			if ($CathID=~/(.{5})\d\d/) {
				my $ChainID = $1;
				my @a;	$a[0] = $CathSeg; $a[1] = $startCath;
				push (@{$mapped_chainCath{$ChainID}},[ @a ]);
				my @b;	$b[0] = $ScopSeg; $b[1] = $startScop;
				push (@{$mapped_chainScop{$ChainID}},[ @b ]);
			} 

		}
	}
	#------------------------End: Get overlapping domain (with cutoff 50% over smaller domain) ----------------#

	#--------------Start: Main Program-----------#

	my %rep = get_representative($representative);
	open LOW_PERCENTAGE, ">", $directory."low_percentage.list";

	my $counter_Cluster=0;  my $perfect_equiv=0; my $lone_equiv=0; 
	my $one_instance=0; my $one_instance_mda=0;
	my %status_chop; my %lone_status; 
	my %lone_mda_status; my %status_Cluster;
	my %cutting; my %uniprotid;
	my %one_instance; my %equivalent; 
	my %one_to_one_sf; my %chopped_domain;
	my %cluster; my %homology_status; 
	my %fold_status; my %class4_status;


	$cluster_sth->execute() or die "! Error: encountered an error when executing SQL statement:\n";

	# go through each cluster
	while ( my $cluster_row = $cluster_sth->fetchrow_hashref ) {

		# some definition
		my $counter_Chain=0;
		my %homology; my %seen_homo; my %match_not_incluster;
		my %match_mda;

		# get nodes
		my $cluster_node = $cluster_row->{CLUSTER_NODE};
		my $nodes = $cluster_row->{NODES};
		my @node = split (/\s+/,$nodes);


		my %hash_node;
		foreach my $node (@node) {$hash_node{$node} = "defined";}	# for fast checking if $domain belong to SF in cluster only

		$cluster{$cluster_node} = "defined";
		# print nodes
		print "\nCluster $cluster_node\n";
		print "------------------------------\nNodes in cluster:\n";
		foreach my $node (@node) {print $node."\t";}
		print "\n\n";

		# get unique chains in cluster BASED ON node (two chains can repeat if belong to diff nodes in cluster)

		my @repeated_chain;
		foreach my $node (@node) {
			foreach my $chain (@{$chain{$node}}) {
				my $SFchain = $node."-".$chain;
				push (@repeated_chain, $SFchain);
			}
		}
		my @uniq_chain = uniq(@repeated_chain);

		# MAIN: for each unique chain
		# print "Chains:\n";
		my $NoOfChain=0; 
		my %seen; my %status_Chain; my %seen_chain_chopped; my %pattern; my %counter_pattern; my %pattern_mapped; my %counter_pattern_mapped;
		my %MDA; my %MDA_incluster_cath; my %MDA_incluster_scop;
		my %MDA_incluster_cath_homo; my %MDA_incluster_scop_homo;
		my %MDA_cath; my %MDA_scop;
		my %Length_cath; my %Length_scop; my %Domain_scop; my %Domain_cath;
		my %seen_incluster_cath; my %seen_incluster_scop; 
		my %seen_incluster_cath_homo; my %seen_incluster_scop_homo; 

		foreach my $uniq_chain (@uniq_chain) {
			if ($rep{$uniq_chain}) {					# only process representative unique chain
				my ($node, $chain) = split (/-/,$uniq_chain);
				if (!$seen{$chain}) {				# get truly unique chain in a cluster
					$NoOfChain++;
					print "\n";
					print $chain."\t";

					# --------------------Start Printing Top Part Of Chain -----------------------# 
					# PRINT $element($scop_id/$cath_id) 	--> @{$domain{}}
					# PRINT $real_region			--> @{$region{}}
					# PRINT $SF{}

					foreach my $element_ord (@{$domain{$chain}}) {					
						my ($element,$ord) = split (/;/,$element_ord);
						if (!$seen{$element}) {
							print $element;								# 1. print domain name
							my ($descriptor,$real_region);
							foreach my $region (@{$region{$element}}) {		
								my $end;
								($descriptor,$real_region) = split (/::/,$region);
								if ($element =~ /\./) {
									print "($region) ";
								}
								else {
									print "($real_region)";					# 2. print region
								}  

							}
							print "[$SF{$element_ord}]  ";					# 3. print SF
							
							if ($element !~ /\./) {
								$seen{$element}="seen";
							}
						}
					}
						
					# --------------------End Printing Top Part Of Chain -----------------------#

					$seen{$chain} = 'seen';							
					print "\n";	

					if ($mapped_chainCath{$chain}) {
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

						#-----------------------MDA pair (in-cluster)----------------------------
						if ($hash_node{$SF{$domord}}) {
							if (!$seen{$domord}) {
								if ($MDA{$uniq_chain}) {$MDA{$uniq_chain} = $MDA{$uniq_chain}."-".$SF{$domord}}
								else {$MDA{$uniq_chain} = $SF{$domord};}
							}
						}
						#-----------------------End MDA pair (in-cluster)----------------------------

						#-----------------------MDA-cath only----------------------------

						if (!$seen{$domord}) {
							if ($MDA_cath{$uniq_chain}) {
								$MDA_cath{$uniq_chain} = $MDA_cath{$uniq_chain}."-".$SF{$domord};
								$Length_cath{$uniq_chain} = $Length_cath{$uniq_chain}."-".$DomainLength{$domord};
								$Domain_cath{$uniq_chain} = $Domain_cath{$uniq_chain}."-".$domord;
							}
							else {
								$MDA_cath{$uniq_chain} = $SF{$domord};
								$Length_cath{$uniq_chain} = $DomainLength{$domord};
								$Domain_cath{$uniq_chain} = $domord;
							}
						}

						#-----------------------End MDA-cath only----------------------------

						if ($hash_node{$SF{$domord}}) {	 # sf in cluster ONLY. uncomment for both scop/cath if want non-clusters ones
							if (!$seen{$domord}) {
								# print "Cath: ".$domord;
								my ($descriptor,$real_region) = split (/::/,$mappedRegion{$domord});
								# print "($real_region) ";

							#-----------------in-cluster MDA----------------------------
								if (!$seen_incluster_cath{$SF{$domord}}) {
									if ($MDA_incluster_cath{$uniq_chain}) {
										$MDA_incluster_cath{$uniq_chain} = $MDA_incluster_cath{$uniq_chain}."-".$SF{$domord};
									}
									else {
										$MDA_incluster_cath{$uniq_chain} = $SF{$domord};
									}
									$seen_incluster_cath{$SF{$domord}} = "seen";
								}
							#-----------------End in-cluster MDA----------------------------

							#-----------------in-cluster MDA: homo----------------------------
								if ($MDA_incluster_cath_homo{$uniq_chain}) {
									$MDA_incluster_cath_homo{$uniq_chain} = $MDA_incluster_cath_homo{$uniq_chain}."-".$SF{$domord};
								}
								else {$MDA_incluster_cath_homo{$uniq_chain} = $SF{$domord};}
							
								#-----------------End in-cluster MDA: homo----------------------------

								$seen{$domord} = "seen";

								my $noMappedDomain = @{$mapped_domain{$domord}};
								# print "Number of Mapped domain ".$noMappedDomain;
								@{$mapped_domain{$domord}} = sort { $a->[1] <=> $b->[1] } @{$mapped_domain{$domord}};

								if ($noMappedDomain > 1) {
									if (!$status_Chain{$uniq_chain}) {
										$status_Chain{$uniq_chain} = "ScopChop"; 
										push (@{$status_chop{$cluster_node}}, "ScopChop");
										$counter_Chain++;
										if (!$seen{$nodes}) {
											$status_Cluster{$cluster_node}="Basic Chopping";
											$counter_Cluster++; 
											$seen{$nodes} = "seen";
										}
									}
									elsif ($status_Chain{$uniq_chain} && $status_Chain{$uniq_chain} eq "CathChop") {
										$status_Chain{$uniq_chain} = "MixedChop"; 
										push (@{$status_chop{$cluster_node}}, "MixedChop");
									}

									# print "\nmatches: ";	
									foreach my $mapped_domord_arr (@{$mapped_domain{$domord}}) 	{
										my @arr_mapped_domord = $mapped_domord_arr;
										my $mapped_domord = $arr_mapped_domord[0][0];
										# print "$mapped_domord	";

										if (!$hash_node{$SF{$mapped_domord}})  {$match_not_incluster{$cluster_node} = "defined";}
									}
									# print "\nPattern: "; print "[$SF{$domord}]	";
									if ($pattern{$uniq_chain}) {
										$pattern{$uniq_chain} = $pattern{$uniq_chain}."[$SF{$domord}]";
									}
									else {
										$pattern{$uniq_chain} = "[$SF{$domord}]";
									}
									foreach my $mapped_domord_arr (@{$mapped_domain{$domord}}) 	{
										my @arr_mapped_domord = $mapped_domord_arr;
										my $mapped_domord = $arr_mapped_domord[0][0];
										#****new
										# print "[$SF{$mapped_domord}] ";
										#****new

										$pattern{$uniq_chain} = $pattern{$uniq_chain}."[$SF{$mapped_domord}]";
									}
									push (@{$cutting{$cluster_node}}, "(1-$noMappedDomain)");
									# print "(1-$noMappedDomain)";

									#----------------------for 'one instance'------------------------
									$chopped_domain{$cluster_node} = $chain;
									#----------------------End for 'one instance'------------------------
								}
								# print "\n";
							} 
							#-------------END if there's ScopChop------------#
						}
					}
					undef %seen_incluster_cath;
					if ($mapped_chainScop{$chain}) {
						@{$mapped_chainScop{$chain}} = sort { $a->[1] <=> $b->[1] } @{$mapped_chainScop{$chain}};
					}
					foreach my $arr_domord (@{$mapped_chainScop{$chain}}) {
						my @arr_domord = $arr_domord;
						my $domord = $arr_domord[0][0];

						#-----------------------MDA pair (in-cluster)----------------------------
						if ($hash_node{$SF{$domord}}) {
							if (!$seen{$domord}) {
								if ($MDA{$uniq_chain}) {$MDA{$uniq_chain} = $MDA{$uniq_chain}."-".$SF{$domord}}
								else {$MDA{$uniq_chain} = $SF{$domord};}
							}
						}
				 #-----------------------MDA pair (in-cluster)----------------------------

				 #-----------------------MDA-scop only----------------------------

						if (!$seen{$domord}) {
							if ($MDA_scop{$uniq_chain}) {
								$MDA_scop{$uniq_chain} = $MDA_scop{$uniq_chain}."-".$SF{$domord};
								$Length_scop{$uniq_chain} = $Length_scop{$uniq_chain}."-".$DomainLength{$domord};
								$Domain_scop{$uniq_chain} = $Domain_scop{$uniq_chain}."-".$domord;
							}
							else {
								$MDA_scop{$uniq_chain} = $SF{$domord};
								$Length_scop{$uniq_chain} = $DomainLength{$domord}; 
								$Domain_scop{$uniq_chain} = $domord;
							}
						}
			
				 		#-----------------------MDA-scop only----------------------------

						if ($hash_node{$SF{$domord}}) {
							if (!$seen{$domord}) {

								# print "Scop: ".$domord;
								my ($descriptor,$real_region) = split (/::/,$mappedRegion{$domord});
								# print "($real_region)\t";

								#-----------------in-cluster MDA----------------------------
								if (!$seen_incluster_scop{$SF{$domord}}) {
									if ($MDA_incluster_scop{$uniq_chain}) {$MDA_incluster_scop{$uniq_chain} = $MDA_incluster_scop{$uniq_chain}."-".$SF{$domord}}
									else {$MDA_incluster_scop{$uniq_chain} = $SF{$domord};}
									$seen_incluster_scop{$SF{$domord}} = "seen";
								}
								#-----------------in-cluster MDA----------------------------

								#-----------------in-cluster MDA: homo----------------------------
								if ($MDA_incluster_scop_homo{$uniq_chain}) {
									$MDA_incluster_scop_homo{$uniq_chain} = $MDA_incluster_scop_homo{$uniq_chain}."-".$SF{$domord};
								}
								else {$MDA_incluster_scop_homo{$uniq_chain} = $SF{$domord};}


								# -----------------End in-cluster MDA: homo----------------------------

								$seen{$domord} = "seen";
								my $noMappedDomain = @{$mapped_domain{$domord}};
								# print "Number of Mapped domain ".$noMappedDomain;
								@{$mapped_domain{$domord}} = sort { $a->[1] <=> $b->[1] } @{$mapped_domain{$domord}};

								#-------------if there's CathChop------------#
		
								if ($noMappedDomain > 1) {
									if(!$status_Chain{$uniq_chain}) {
										$status_Chain{$uniq_chain} = "CathChop"; 
										push (@{$status_chop{$cluster_node}}, "CathChop");
									#elsif ($domord =~/^[a-z]/) {$status_Chain{$uniq_chain} = "CathChop"; $status_chop{$cluster_node} = "CathChop";}
										$counter_Chain++;
										if (!$seen{$nodes}) {
											$status_Cluster{$cluster_node}="Basic Chopping";
											$counter_Cluster++; 
											$seen{$nodes} = "seen";
										}
									}
									elsif ($status_Chain{$uniq_chain} && $status_Chain{$uniq_chain} eq "ScopChop") {
										$status_Chain{$uniq_chain} = "MixedChop"; 
										push (@{$status_chop{$cluster_node}}, "MixedChop");
									}


									# print "\nmatches: ";	
									foreach my $mapped_domord_arr (@{$mapped_domain{$domord}}) 	{
										my @arr_mapped_domord = $mapped_domord_arr;
										my $mapped_domord = $arr_mapped_domord[0][0];
										# print "$mapped_domord	";

										if (!$hash_node{$SF{$mapped_domord}})  {$match_not_incluster{$cluster_node} = "defined";}
										if ($SF{$mapped_domord} =~ /^4/) {$class4_status{$cluster_node} = "defined";}
									}
									# print "\n		Pattern: "; print "[$SF{$domord}]	";
									if ($pattern{$uniq_chain}) {
										$pattern{$uniq_chain} = $pattern{$uniq_chain}."[$SF{$domord}]";
									}
									else {
										$pattern{$uniq_chain} = "[$SF{$domord}]";
									}
									foreach my $mapped_domord_arr (@{$mapped_domain{$domord}}) 	{
										my @arr_mapped_domord = $mapped_domord_arr;
										my $mapped_domord = $arr_mapped_domord[0][0];

										#****new
										# print "[$SF{$mapped_domord}] ";
										#****new

										$pattern{$uniq_chain} = $pattern{$uniq_chain}."[$SF{$mapped_domord}]";
									}
									push (@{$cutting{$cluster_node}}, "(1-$noMappedDomain)");
									# print "(1-$noMappedDomain)";

									#----------------------for 'one instance'------------------------
									$chopped_domain{$cluster_node} = $chain;
									#----------------------for 'one instance'------------------------
								}
					
								# print "\n";
							} 
							#-------------END if there's CathChop------------#
						}  
					}
					undef %seen_incluster_scop;

					#--------------------------Start Print Chain Stuff----------#
					# PRINT $status_Chain{}
					# PRINT $pattern{}
					# GET $counter_pattern{}
					# PRINT $counter_patter{}

					if ($status_Chain{$uniq_chain}) {							
						print "Status of this chain is : ".$status_Chain{$uniq_chain}."\n";
						print "Pattern of this chain is : ".$pattern{$uniq_chain}."\n";			

						if ($counter_pattern{$pattern{$uniq_chain}}) {
							$counter_pattern{$pattern{$uniq_chain}}++;
						}
						else {
							$counter_pattern{$pattern{$uniq_chain}} = 1;
						}
						# print "Counting... $counter_pattern{$pattern{$uniq_chain}}\n";
					}	
					# if ( $pattern_mapped{$uniq_chain}) {
					#	print "Pattern of this chain including single is : ".$pattern_mapped{$uniq_chain}."\n";

					#	if ( $counter_pattern_mapped{$pattern_mapped{$uniq_chain}}) {
					#		$counter_pattern_mapped{$pattern_mapped{$uniq_chain}}++;
					#	}
					#	else {
					#		$counter_pattern_mapped{$pattern_mapped{$uniq_chain}} = 1;
					#	}
					#	print "Counting mapped... $counter_pattern_mapped{$pattern_mapped{$uniq_chain}}\n";

					# }

					# if ( $MDA{$uniq_chain}) {print "MDA of this chain is (only in-cluster): $MDA{$uniq_chain}\n";} 
					# if ( $MDA_cath{$uniq_chain}) {print "MDA of this chain (include off-cluster) for cath is: $MDA_cath{$uniq_chain}\n";} 
					# if ( $Length_cath{$uniq_chain}) {print "Length of MDA include off-cluster: $Length_cath{$uniq_chain}\n";}
					# if ( $MDA_scop{$uniq_chain}) {print "MDA of this chain (include off-cluster) for scop is: $MDA_scop{$uniq_chain}\n";}
					# if ( $Length_scop{$uniq_chain}) {print "Length of MDA include off-cluster: $Length_scop{$uniq_chain}\n";}
					if ($MDA_cath{$uniq_chain} && $MDA_scop{$uniq_chain}) {
						my @c;	$c[0] = $MDA_scop{$uniq_chain}; $c[1] = $Length_scop{$uniq_chain}; $c[2] = $Domain_scop{$uniq_chain}; 
						push (@{$match_mda{$MDA_cath{$uniq_chain}}}, [ @c ]);
						my @d;	$d[0] = $MDA_cath{$uniq_chain}; $d[1] = $Length_cath{$uniq_chain}; $d[2] = $Domain_cath{$uniq_chain};
						push (@{$match_mda{$MDA_scop{$uniq_chain}}}, [ @d ]);
					}
					# if ( $MDA_incluster_cath{$uniq_chain}) {print "In-cluster MDA of this chain for cath is: $MDA_incluster_cath{$uniq_chain}\n";} 
					# if ( $MDA_incluster_scop{$uniq_chain}) {print "In-cluster MDA of this chain for scop is: $MDA_incluster_scop{$uniq_chain}\n";} 
					#--------------homology---------------------

					if ( $MDA_incluster_cath{$uniq_chain} && $MDA_incluster_scop{$uniq_chain}) {

						if (!$seen_homo{$MDA_incluster_scop{$uniq_chain}}) {
							push (@{$homology{$MDA_incluster_cath{$uniq_chain}}}, $MDA_incluster_scop{$uniq_chain});
							$seen_homo{$MDA_incluster_scop{$uniq_chain}} = "seen";
						}

						if (!$seen_homo{$MDA_incluster_cath{$uniq_chain}}) {
							push (@{$homology{$MDA_incluster_scop{$uniq_chain}}}, $MDA_incluster_cath{$uniq_chain});
							$seen_homo{$MDA_incluster_cath{$uniq_chain}} = "seen";
						}
					} 
					#-------------homology----------------------
					
					#if ( $MDA_incluster_cath_homo{$uniq_chain}) {
					#print "In-cluster MDA of this chain for cath (homo) is: $MDA_incluster_cath_homo{$uniq_chain}\n";
					#} 
					#if ( $MDA_incluster_scop_homo{$uniq_chain}) {
					#print "In-cluster MDA of this chain for scop (homo) is: $MDA_incluster_scop_homo{$uniq_chain}\n";
					#} 
					#----------------------End Print Chain Stuff---------------#				

				}													
			} # REPRESENTATIVE  
		}



		#--------------------------Start Print Cluster Stuff-------------------------#
		# PRINT $NoOfChain
		# PRINT Basic Chopping 	--> $counter_Chain
		# GET $lone_status{} 	--> based on $NoOfChain & $counter_Chain
		# GET $one_instance{}	--> based on $counter_Chain
		# PRINT "Pattern in this cluster"	--> %pattern	&	%counter_pattern{}
		# GET $equivalent{}
		# PRINT $equivalent{}
		
		print "\nThis cluster has $NoOfChain unique chains.\n";	
		
		print "Out of those, $counter_Chain has basic chopping.\n";						

		if ($NoOfChain==$counter_Chain) {
			if ($NoOfChain==1) {
					$lone_equiv++; 
					print "Lone equivalent....\n"; 
					$lone_status{$cluster_node}="defined";
				}
			else {
				$perfect_equiv++; 
				print "Complete equivalent!!!\n";
			}
		}							# Golden split...
		elsif ($counter_Chain==1) {
			$one_instance++; 
			print "One instance for $cluster_node----\n"; 
			$one_instance{$cluster_node}=$chopped_domain{$cluster_node}; 
		}
			
		undef %hash_node;

		if ($counter_Chain > 0) {
			print "Pattern in this cluster : \n";
			my %seen_pattern;
			my %seen_pattern_mapped;
			my $pattern_count = 0;
			foreach my $chain (keys %pattern) {
				if ($seen_pattern{$pattern{$chain}}) {}
				else {
					$pattern_count++;
					print $pattern{$chain}."\t"."($counter_pattern{$pattern{$chain}})\n";
					$seen_pattern{$pattern{$chain}} = "seen";

					if ($counter_pattern{$pattern{$chain}} > 1) {$equivalent{$cluster_node} = "defined"; }
				}
			}
			##print "\nPattern count = $pattern_count\n";
			#print "Pattern including single domain matches:\n";
			#foreach my $chain (keys %pattern_mapped) {
			#if ($seen_pattern_mapped{$pattern_mapped{$chain}}) {}
			#else {
			# print $pattern_mapped{$chain}."\t"."($counter_pattern_mapped{$pattern_mapped{$chain}})\n";
			# $seen_pattern_mapped{$pattern_mapped{$chain}} = "seen";
			#}
			#}
		}

		print "\nPercentages\n-----------\n";
		
		foreach my $mda (keys %match_mda) {
			my %seen_matching_mda;
			if ($mda !~/^\d/) {
				print $mda.": \n";
				my $total_matching_mda = @{$match_mda{$mda}};
				my %matching_mda_count;
				foreach my $matching_mda_arr (@{$match_mda{$mda}}) {
					my @arr_matching_mda = $matching_mda_arr;
					my $matching_mda = $arr_matching_mda[0][0];
					if ( $matching_mda_count{$matching_mda}) {
						$matching_mda_count{$matching_mda}++;
					}
					else {$matching_mda_count{$matching_mda} = 1;}
				}

				foreach my $matching_mda_arr (@{$match_mda{$mda}}) {
					my @arr_matching_mda = $matching_mda_arr;
					my $matching_mda = $arr_matching_mda[0][0];
					my $matching_mda_length = $arr_matching_mda[0][1];
					my $matching_mda_domain = $arr_matching_mda[0][2];

					if (!$seen_matching_mda{$matching_mda}){
						my $percent = ($matching_mda_count{$matching_mda}/$total_matching_mda)*100;
						$percent = sprintf("%.3f", $percent);

						if ($percent != 100) {
							print $matching_mda."\t";
							#print $matching_mda_length."\t";
							#print $matching_mda_domain."\t";
							print $matching_mda_count{$matching_mda}."\tPercent: $percent\n";
							print $matching_mda_domain."\n";
							if ($percent < 5) {
								print "*LOW PERCENTAGE*\n";
								print LOW_PERCENTAGE "$cluster_node\tMDA: $mda\tMatch: $matching_mda\t Percent:$percent\t"; 
								#print LOW_PERCENTAGE "\t\t\t\t\t\t\t".
								print LOW_PERCENTAGE "Domain: ".$matching_mda_domain."\n";
							}
							$seen_matching_mda{$matching_mda} = "seen";
						}
					}
				}
				print "\n\n";
			}
		}
		print "\n";



		my %seen_mda; my %mda_count;
		my %seen_mda_incluster; my %mda_count_incluster_cath; my %mda_count_incluster_scop;
		print "\nMDA pairing of this cluster (in-cluster): \n";
		foreach my $chain (keys %MDA) {
			if (!$seen_mda{$MDA{$chain}}) {
				if ($MDA{$chain} =~ /-/) {
					if ( $mda_count{$cluster_node}) {$mda_count{$cluster_node}++;}
					else {$mda_count{$cluster_node} = 1;}
					print $MDA{$chain}."\n";
					$seen_mda{$MDA{$chain}} = "seen";
				}
			}
		}
		print "In-cluster MDA for CATH for this cluster: \n";

		my %homo_in_chain;
		foreach my $chain (keys %MDA_incluster_cath) {
			if (!$seen_mda_incluster{$MDA_incluster_cath{$chain}}) {
				if ( $mda_count_incluster_cath{$cluster_node}) {$mda_count_incluster_cath{$cluster_node}++;}
				else {$mda_count_incluster_cath{$cluster_node} = 1;}
				print $MDA_incluster_cath{$chain}."\n";
				$seen_mda_incluster{$MDA_incluster_cath{$chain}} = "seen";

				if ($MDA_incluster_cath{$chain} =~ /-/) {$homo_in_chain{$cluster_node} = "defined";}
			}
		}
		print "In-cluster MDA for SCOP for this cluster: \n";
		foreach my $chain (keys %MDA_incluster_scop) {
			if (!$seen_mda_incluster{$MDA_incluster_scop{$chain}}) {
				if ( $mda_count_incluster_scop{$cluster_node}) {$mda_count_incluster_scop{$cluster_node}++;}
				else {$mda_count_incluster_scop{$cluster_node} = 1;}
				print $MDA_incluster_scop{$chain}."\n";
				$seen_mda_incluster{$MDA_incluster_scop{$chain}} = "seen";

				if ($MDA_incluster_scop{$chain} =~ /-/) {$homo_in_chain{$cluster_node} = "defined";}
			}
		}

		if ( $equivalent{$cluster_node}) {print "This cluster has equivalent split\n";}
		if ($mda_count{$cluster_node} == 1 && !$match_not_incluster{$cluster_node}) {
			print "One instance MDA----\n"; 
			if ( $status_Cluster{$cluster_node}){$lone_mda_status{$cluster_node} = "defined"; $one_instance_mda++;}
		}
		if ($mda_count_incluster_cath{$cluster_node} == 1 && $mda_count_incluster_scop{$cluster_node} == 1) {
			$one_to_one_sf{$cluster_node} = "defined";
			if ($homo_in_chain{$cluster_node}) {print "This cluster has consistent but multiple homology.\n";} 
			else {print "This cluster has consistent homology.\n";}
			
		}

		print "#---HOMOLOGY---#";
		foreach my $homo_keys (keys %homology) {
			
			my $homo_match_count = @{$homology{$homo_keys}};
			if ($homo_match_count > 1) {
				if ( $homology_status{$cluster_node}) {
					my $current_homology_status;
					if ($homo_keys =~/^\d/) {$current_homology_status = "ScopHom";}
					else {$current_homology_status = "CathHom";}

					if ($homology_status{$cluster_node} ne $current_homology_status) {
						$homology_status{$cluster_node} = "MixedHom";
					}
				}
				else {
					if ($homo_keys =~/^\d/) {$homology_status{$cluster_node} = "ScopHom";}
					else {$homology_status{$cluster_node} = "CathHom";}
				}
			}
			print "\n$homo_keys:\t";
			my %seen_sf_fold; my %seen_fold;
			foreach my $homo_match (@{$homology{$homo_keys}}) {
				# my $fold_status; 

				print $homo_match."\t";
				my @superfamily_cath = ($homo_match =~ /(\d+\.\d+\.\d+\.\d+)/g);
				my @superfamily_scop = ($homo_match =~ /([a-z]+\.\d+\.\d+)/g);
				@superfamily_cath = uniq(@superfamily_cath);
				@superfamily_scop = uniq(@superfamily_scop);			

				foreach my $superfamily (@superfamily_cath) {
					my $fold;
					if ($superfamily =~ /(\d+\.\d+\.\d+)\.\d+/) {$fold = $1;}
					if (!$seen_sf_fold{$superfamily}) {
						print "(fold = ".$fold.")\t"; 
						if ($seen_fold{$fold}) {
							if ( $fold_status{$cluster_node} && $fold_status{$cluster_node} eq "MixedHom") {}
							elsif ( $fold_status{$cluster_node} && $fold_status{$cluster_node} eq "ScopHom") {
								$fold_status{$cluster_node} = "MixedHom"; 
							}
							else {
								$fold_status{$cluster_node} = "CathHom"; 
							}
							print "+++ THIS CLUSTER HAS SAME FOLD which is $fold_status{$cluster_node}+++\n";
						}
						$seen_fold{$fold} = "seen";
						$seen_sf_fold{$superfamily} = "seen";
					}
				}
				foreach my $superfamily (@superfamily_scop) {			
					my $fold;
					if ($superfamily =~ /(^[a-z]\.\d+)\.\d+/) {$fold = $1;}
					if ($seen_sf_fold{$superfamily}) {}
					else {
						print "(fold = ".$fold.")\t"; 
						if ($seen_fold{$fold}) {
							if ( $fold_status{$cluster_node} && $fold_status{$cluster_node} eq "MixedHom") {}
							elsif ( $fold_status{$cluster_node} && $fold_status{$cluster_node} eq "CathHom") {
								$fold_status{$cluster_node} = "MixedHom"; 
							}
							else {
								$fold_status{$cluster_node} = "ScopHom"; 
							}
							print "+++ THIS CLUSTER HAS SAME FOLD which is $fold_status{$cluster_node}+++\n";
						}
						$seen_fold{$fold} = "seen";
						$seen_sf_fold{$superfamily} = "seen";
					}
				}
				#foreach my $fold (@fold) {
				#print "(fold = ".$fold.")\t";
				 #if ( $fold) {
				#if ($seen{$fold}) {$fold_status = "defined"; print "+++ THIS CLUSTER HAS SAME FOLD +++\n";}
				#$seen{$fold} = "seen";
				 #}
				#}
			}
		}
		print "\n#---HOMOLOGY---#";
		if ( $homology_status{$cluster_node}) {print "\n*** THIS CLUSTER HAS HOMOLOGY DIFFERENCE which is $homology_status{$cluster_node}***"};
		if ( $fold_status{$cluster_node}) {print "\n+++ THIS CLUSTER HAS FOLD DIFFERENCE+++ which is $fold_status{$cluster_node}"};
		print "\n";											
		#--------------------------End Print Cluster Stuff-------------------------#
	}

	#--------------End: Main Program-----------#

	#-------------------------------Start PRINT TO FILE: BAS_CHOP -------------------------------------#
	# GET @complex_case	-->  @{$status_chop{}
	# GET @OneType_case	-->  @{$status_chop{}
	my $complex_case = 0; my $OneType_case=0;
	my (@OneType_case); my %complex_case;
	my %onetype;

	open BAS_CHOP, ">", $directory."BasicChop.list";
	print BAS_CHOP "List of Basic Chopping:\n";
	foreach my $cluster_rep (keys %status_Cluster) {
		if ($status_Cluster{$cluster_rep} eq "Basic Chopping") {
			print BAS_CHOP $cluster_rep."\t";
			
			@{$status_chop{$cluster_rep}} = uniq(@{$status_chop{$cluster_rep}});
			my $chop_cases = @{$status_chop{$cluster_rep}};
			if ($chop_cases > 1) {
				$complex_case++;
				$complex_case{$cluster_rep} = "defined";
			}
			else {
				$OneType_case++;
				push (@OneType_case,$cluster_rep);
				foreach my $status (@{$status_chop{$cluster_rep}}) {
				  $onetype{$cluster_rep} = $status;
				}
			}
			foreach my $status (@{$status_chop{$cluster_rep}}) {
				print BAS_CHOP $status."\t";
			}
			print BAS_CHOP "\n";
		}
	}
	#-------------------------------End PRINT TO FILE: BAS_CHOP -------------------------------------#

	#-------------------------------Start PRINT TO FILE: ONETYPE -------------------------------------#
	# PRINT @OneType_case
	# PRINT @{$status_chop{}
	# PRINT $lone_status{}
	# PRINT $one_instance{}
	# PRINT @{$cutting{}}
	# GET @{cutting_nosolo{}}	---> based on $lone_status{} & $one_instance{}m

	my %cutting_nosolo;
	open ONETYPE, ">", $directory."onetype.list";
	open CATHTYPE_CHOP, ">", $directory."onetype-cath_chop.list";
	open CATHTYPE_CHOP_HOMO, ">", $directory."onetype-cath_chop_homo.list";
	open SCOPTYPE_CHOP, ">", $directory."onetype-scop_chop.list";
	open SCOPTYPE_CHOP_HOMO, ">", $directory."onetype-scop_chop_homo.list";
	open CATHTYPE_CHOP_SAMEFOLD, ">", $directory."onetype-cath_chop_samefold.list";
	open CATHTYPE_CHOP_HOMO_SAMEFOLD, ">", $directory."onetype-cath_chop_homo_samefold.list";
	# open SCOPTYPE_CHOP_SAMEFOLD, ">", $directory."onetype-scop_chop_samefold.list";
	open SCOPTYPE_CHOP_HOMO_SAMEFOLD, ">", $directory."onetype-scop_chop_homo_samefold.list";
	open SOLO, ">", $directory."solo.list";
	open SOLO_MDA, ">", $directory."solo_mda.list";
	open SOLO_MDA_COMP_EQUIV, ">",$directory."solo_mda_comp.list";
	open SOLO_MDA_NO_EQUIV, ">",$directory."solo_mda_no_equiv.list";
	open ONE_INSTANCE_CHOP, ">", $directory."one_instance_chop.list";
	open ONE_INSTANCE_CHOP_HOMO, ">", $directory."one_instance_chop_homo.list";
	open ONE_INSTANCE, ">", $directory."oneinstance.list";
	my $one_instance_onetype = 0; 
	my $lone_mda_onetype = 0;
	my $basic_cath_counter = 0;
	my $basic_scop_counter = 0;
	my $basic_minus_LoneAndOneInstance_cath_counter = 0;
	my $basic_minus_LoneAndOneInstance_scop_counter = 0;
	my $basic_minus_LoneAndOneInstance_cath_CHOP_counter = 0;
	my $basic_minus_LoneAndOneInstance_cath_CHOP_HOMO_counter = 0;
	my $basic_minus_LoneAndOneInstance_scop_CHOP_counter = 0;
	my $basic_minus_LoneAndOneInstance_scop_CHOP_HOMO_counter = 0;
	my $solo_mda_comp_equiv = 0; my $solo_mda_no_equiv = 0;
	my $one_instance_chop = 0; my $one_instance_chop_homo = 0;
	my $one_instance_chop_cath = 0; my $one_instance_chop_homo_cath = 0;
	my $one_instance_chop_scop = 0; my $one_instance_chop_homo_scop = 0;

	# ------print ALL ---------------

	writeInFileIfDefined($directory, "all_lona_mda.list", \%lone_mda_status, \%fold_status);
	writeInFileIfDefined($directory, "all_one_instance.list", \%one_instance, \%fold_status);
	writeInFileIfDefined($directory, "all_onetype.list", \%onetype, \%fold_status);
	writeInFileIfDefined($directory, "all_class4.list", \%class4_status, \%fold_status);

	writeInFile($directory, "all_homology.list", \%homology_status);
	writeInFile($directory, "all_chop.list", \%status_Cluster);
	writeInFile($directory, "all_samefold.list", \%fold_status);


	open COMPLEX_ALL, ">", $directory."all_complex.list";
	foreach my $complex (keys %complex_case) {
		if (!$homology_status{$complex}) {
			print COMPLEX_ALL $complex."\n";
		}
	}

	# ------end print ALL ----------------


	foreach my $onetype (@OneType_case) {

		#------------count onetype AND one instance ---------------#
		if ($one_instance{$onetype}) {
			print ONE_INSTANCE $onetype."\n";
		}
		#------------count onetype AND one instance ---------------#

		#------------count onetype AND one instance ---------------#
		if ($one_instance{$onetype} && !$lone_mda_status{$onetype}) {
			if (defined $one_instance_onetype) {$one_instance_onetype++;}
			else {$one_instance_onetype = 1;}
		}
		#------------count onetype AND one instance ---------------#

		#------------count onetype AND one instance MDA ---------------#
		if ($lone_mda_status{$onetype} && !$lone_status{$onetype}) {
			if (defined $lone_mda_onetype) {$lone_mda_onetype++;}
			else {$lone_mda_onetype = 1;}
		}
		#------------count onetype AND one instance MDA ---------------#

		print ONETYPE "$onetype\t";
		foreach my $status (@{$status_chop{$onetype}}) {
			print ONETYPE $status."\t";

			if ($status eq "CathChop") {
				$basic_cath_counter++;
			}
			elsif ($status eq "ScopChop") {
				$basic_scop_counter++;
			}

			if ($lone_status{$onetype}) {
				print ONETYPE "Solo case\t";
				print SOLO $onetype."\t";
				print SOLO $status."\t";
				if ( $class4_status{$onetype}) {
					print SOLO "class4";
				}
				print SOLO "\n";
			}
			else {print ONETYPE "---------\t"};

			if ( $lone_mda_status{$onetype}) {
				print ONETYPE "Solo MDA\t";
			}		
			else {print ONETYPE "--------\t"};

			if ( $one_instance{$onetype}) {
				print ONETYPE "One instance\t";
			}		
			else {print ONETYPE "-----------\t"};

			if ( $one_instance{$onetype} && ! $lone_mda_status{$onetype} &&  $one_to_one_sf{$onetype} ) {
			if ($status eq "CathChop") {
				$one_instance_chop++;
				$one_instance_chop_cath++;
			}
			elsif ($status eq "ScopChop") {
				$one_instance_chop++;
				$one_instance_chop_scop++;
			}
			print ONE_INSTANCE_CHOP $onetype."\t";
			print ONE_INSTANCE_CHOP $status."\t";
			print ONE_INSTANCE_CHOP $one_instance{$onetype}."\t";
			if ( $class4_status{$onetype}) {print ONE_INSTANCE_CHOP "class4";}
				print ONE_INSTANCE_CHOP "\n";
			}
			if ( $one_instance{$onetype} && ! $lone_mda_status{$onetype} && ! $one_to_one_sf{$onetype} ) {
			if ($status eq "CathChop") {
				$one_instance_chop_homo++;
				$one_instance_chop_homo_cath++;
			}
			elsif ($status eq "ScopChop") {
				$one_instance_chop_homo++;
				$one_instance_chop_homo_scop++;
			}
			print ONE_INSTANCE_CHOP_HOMO $onetype."\t";
			print ONE_INSTANCE_CHOP_HOMO $status."\t";
			print ONE_INSTANCE_CHOP_HOMO $one_instance{$onetype}."\t";
			if ( $class4_status{$onetype}) {print ONE_INSTANCE_CHOP_HOMO "class4";}
				print ONE_INSTANCE_CHOP_HOMO "\n";
			}

			@{$cutting{$onetype}} = uniq(@{$cutting{$onetype}});

			foreach my $cut (@{$cutting{$onetype}}) {
				print ONETYPE $cut."\t";
			}
			if ( $lone_mda_status{$onetype} && ! $lone_status{$onetype}) {
				print SOLO_MDA $onetype."\t";
				print SOLO_MDA $status."\n";
			}
			if ( $lone_mda_status{$onetype} && ! $lone_status{$onetype} &&  $equivalent{$onetype}) {
				$solo_mda_comp_equiv++;
				print SOLO_MDA_COMP_EQUIV $onetype."\t";
				print SOLO_MDA_COMP_EQUIV $status."\t";
				if ( $class4_status{$onetype}) {print SOLO_MDA_COMP_EQUIV "class4"}
					print SOLO_MDA_COMP_EQUIV "\n";
			}
			if ( $lone_mda_status{$onetype} && ! $lone_status{$onetype} && ! $equivalent{$onetype}) {
				$solo_mda_no_equiv++;
				print SOLO_MDA_NO_EQUIV $onetype."\t";
				print SOLO_MDA_NO_EQUIV $status."\t";
				if ( $class4_status{$onetype}) {print SOLO_MDA_NO_EQUIV "class4"}
					print SOLO_MDA_NO_EQUIV "\n";
			}
		}
		print ONETYPE "\n";	
	}
	#-------------------------------End PRINT TO FILE: ONETYPE -------------------------------------#

	#-------------------------------PRINT: ONETYPE BASIC -----------------------------------------#
	foreach my $onetype (keys %onetype) {
	 # Completely basic chopping, minus 'uninteresting' & 'interesting cases
		my $status = $onetype{$onetype};

		if (! $lone_mda_status{$onetype} && ! $one_instance{$onetype} && ! $class4_status{$onetype}) {
			if ($status eq "CathChop") {
				$basic_minus_LoneAndOneInstance_cath_counter++;
				if ( $one_to_one_sf{$onetype} &&  $fold_status{$onetype}) {
					$basic_minus_LoneAndOneInstance_cath_CHOP_counter++;
					print CATHTYPE_CHOP_SAMEFOLD $onetype."\t".$status."\t";
					print CATHTYPE_CHOP_SAMEFOLD "\n";
				}
				elsif ( $one_to_one_sf{$onetype} && ! $fold_status{$onetype}) {
					$basic_minus_LoneAndOneInstance_cath_CHOP_counter++;
					print CATHTYPE_CHOP $onetype."\t".$status."\t";
					print CATHTYPE_CHOP "\n";
				} #only those with samefold are printed first
				elsif (! $fold_status{$onetype}) {
					$basic_minus_LoneAndOneInstance_cath_CHOP_HOMO_counter++;
					print CATHTYPE_CHOP_HOMO $onetype."\t".$status."\t";
					print CATHTYPE_CHOP_HOMO "\n";
				}
				else {
					$basic_minus_LoneAndOneInstance_cath_CHOP_HOMO_counter++;
					print CATHTYPE_CHOP_HOMO_SAMEFOLD $onetype."\t".$status."\t";
					print CATHTYPE_CHOP_HOMO_SAMEFOLD "\n";
				}
		 	}
		 	elsif ($status eq "ScopChop") {
				$basic_minus_LoneAndOneInstance_scop_counter++;

				if ( $one_to_one_sf{$onetype} &&  $fold_status{$onetype}) {
					$basic_minus_LoneAndOneInstance_scop_CHOP_counter++;
					print SCOPTYPE_CHOP_FOLD $onetype."\t".$status."\t";
					print SCOPTYPE_CHOP_FOLD "\n";
				}
				elsif ( $one_to_one_sf{$onetype} && ! $fold_status{$onetype}) {
					$basic_minus_LoneAndOneInstance_scop_CHOP_counter++;
					print SCOPTYPE_CHOP $onetype."\t".$status."\t";
					print SCOPTYPE_CHOP "\n";

				} #only those with samefold are printed first
				elsif (! $fold_status{$onetype}) {
					$basic_minus_LoneAndOneInstance_scop_CHOP_HOMO_counter++;
					print SCOPTYPE_CHOP_HOMO $onetype."\t".$status."\t";
					print SCOPTYPE_CHOP_HOMO "\n";
				}
				else {
					$basic_minus_LoneAndOneInstance_scop_CHOP_HOMO_counter++;
					print SCOPTYPE_CHOP_HOMO_SAMEFOLD $onetype."\t".$status."\t";
					print SCOPTYPE_CHOP_HOMO_SAMEFOLD "\n";
			 	}
		 	}
		 	foreach my $cut (@{$cutting{$onetype}}) {
				if ($cut =~ /1-(\d+)/) {push (@{$cutting_nosolo{$onetype}},$1);}
		 	}
			@{$cutting_nosolo{$onetype}} = sort @{$cutting_nosolo{$onetype}};
		} 
	}
	#-------------------------------End: ONETYPE BASIC ------------------------------------------#

	#-------------------------------Start PRINT TO FILE: CUTTING_NOSOLO -------------------------------------#
	# PRINT @{cutting_nosolo{}}
	# PRINT @{$cutting{}}
	open CUTTING_NOSOLO, ">", $directory."cutting_nosolo.list";
	for my $cluster_rep (sort {$cutting_nosolo{$a}[0] <=> $cutting_nosolo{$b}[0]} keys %cutting_nosolo) {
			# bbb c aaaa
		my $no_of_cut = @{$cutting{$cluster_rep}};
		if ($no_of_cut==1) {
			print CUTTING_NOSOLO $cluster_rep, "\t";
			foreach my $cut (@{$cutting{$cluster_rep}}) {
				print CUTTING_NOSOLO $cut."\t";
			}
			print CUTTING_NOSOLO "\n";
		}	
	}
	#-------------------------------End PRINT TO FILE: CUTTING_NOSOLO -------------------------------------#

	#-------------------------------Start PRINT TO FILE: EQUIV SPLIT -------------------------------------#
	my $equivalent_com_count = 0; my $equivalent_no_count = 0;
	my $equivalent_no_count_complex = 0; my $equivalent_no_count_cath = 0; my $equivalent_no_count_scop = 0;
	my $equivalent_no_count_cath_chop = 0; my $equivalent_no_count_scop_chop = 0;
	my $equivalent_no_count_cath_chop_homo = 0; my $equivalent_no_count_scop_chop_homo = 0;
	open EQUIV, ">", $directory."equivalentsplit.list";
	open EQUIV_CATH, ">", $directory."equivalentsplit_cath.list";
	open EQUIV_SCOP, ">", $directory."equivalentsplit_scop.list";
	open EQUIV_CATH_CHOP, ">", $directory."equivalentsplit_cath_chop.list";
	open EQUIV_CATH_CHOP_HOMO, ">", $directory."equivalentsplit_cath_chop_homo.list";
	open EQUIV_SCOP_CHOP, ">", $directory."equivalentsplit_scop_chop.list";
	open EQUIV_SCOP_CHOP_HOMO, ">", $directory."equivalentsplit_scop_chop_homo.list";

	foreach my $equivalentsplit (keys %equivalent) {
		if ( $lone_mda_status{$equivalentsplit}) {
			## These are compelte equivalents already in solo_mda.list
			$equivalent_com_count++;
		}
		else {
			print EQUIV $equivalentsplit."\t";
			foreach my $status (@{$status_chop{$equivalentsplit}}) {
				print EQUIV $status."\t";
			}
			print EQUIV "\n";
		  if ( $onetype{$equivalentsplit} && $onetype{$equivalentsplit} eq "CathChop") {
				$equivalent_no_count_cath++;
				print EQUIV_CATH "$equivalentsplit\t"; 
				print EQUIV_CATH $onetype{$equivalentsplit}."\n";
			  if ( $one_to_one_sf{$equivalentsplit}) { 
					$equivalent_no_count_cath_chop++;
					print EQUIV_CATH_CHOP "$equivalentsplit\n";
			  }
			  else {
					$equivalent_no_count_cath_chop_homo++;
					print EQUIV_CATH_CHOP_HOMO "$equivalentsplit\n";
			  }
		  }
		  elsif ( $onetype{$equivalentsplit} &&  $onetype{$equivalentsplit} eq "ScopChop") {
				$equivalent_no_count_scop++;
			
				print EQUIV_SCOP "$equivalentsplit\t"; 
				print EQUIV_SCOP $onetype{$equivalentsplit}."\n";

				if ( $one_to_one_sf{$equivalentsplit}) { 
					$equivalent_no_count_scop_chop++;
					print EQUIV_SCOP_CHOP "$equivalentsplit\n";
			  }
			  else {
					$equivalent_no_count_scop_chop_homo++;
					print EQUIV_SCOP_CHOP_HOMO "$equivalentsplit\n";
			  }
			}
		  else {
				$equivalent_no_count_complex++;
		  }
			$equivalent_no_count++;
		}
	}
	#-------------------------------End PRINT TO FILE: EQUIV SPLIT -------------------------------------#

	open MIXED, ">", $directory."mixedcase.list";

	foreach my $mixedtype (keys %complex_case) {
		print MIXED $mixedtype."\n";
	}

	#--------------------------Start Print Homology cases --------------------#
	open HOMOLOGY, ">", $directory."homology.list";
	open HOMO_CHOP, ">", $directory."homology_with_chop_simpler.list";
	open HOMO_CHOP_GENERAL, ">", $directory."homology_with_chop.list";
	open HOMOLOGY_CATHHOM, ">", $directory."homology_cathhom.list";
	open HOMOLOGY_SCOPHOM, ">", $directory."homology_scophom.list";
	open HOMOLOGY_MIXEDHOM, ">", $directory."homology_mixedhom.list";
	foreach my $nodes (keys %homology_status) {
		if ( $status_Cluster{$nodes}) {
			print HOMO_CHOP_GENERAL $nodes."\n";
		}
		if (! $complex_case{$nodes}) {
			if ( $status_Cluster{$nodes}) {
				print HOMO_CHOP $nodes."\t"."WITH CHOPPING\t";
				if ($onetype{$nodes}) {print HOMO_CHOP "onetype\t$onetype{$nodes}\t";}
				else {print HOMO_CHOP "-------\t--------\t";}
				if ( $lone_mda_status{$nodes}) {print HOMO_CHOP "lone case\t";}
				else {print HOMO_CHOP "---------\t";}
				if ( $one_instance{$nodes}) {print HOMO_CHOP "one instance\t";}
				else {print HOMO_CHOP "------------\t";}
				if ( $equivalent{$nodes}) {print HOMO_CHOP "equivalent\t";}
				else {print HOMO_CHOP "----------\t";}
				print HOMO_CHOP "\n";
			}
			else {
				if (! $fold_status{$nodes}) {
					print HOMOLOGY $nodes."\t".$homology_status{$nodes}."\n";
					if ($homology_status{$nodes} eq "CathHom") {print HOMOLOGY_CATHHOM $nodes."\t".$homology_status{$nodes}."\n";}
					if ($homology_status{$nodes} eq "ScopHom") {print HOMOLOGY_SCOPHOM $nodes."\t".$homology_status{$nodes}."\n";}
					if ($homology_status{$nodes} eq "MixedHom") {print HOMOLOGY_MIXEDHOM $nodes."\t".$homology_status{$nodes}."\n";}
			  }
			}
	 	}
	}
	#-------------------------End Print Homology cases -----------------------#

	#-------------------------Chop + Homo-------------------------------------#
	open CHOP_HOMO, ">", $directory."chopping_with_homology.list";
	foreach my $nodes (keys %status_Cluster) {
		if ( $homology_status{$nodes}) {
			print CHOP_HOMO $nodes."\n";
		}
	}
	#-------------------------Chop + Homo-------------------------------------#

	#-------------------------Start printing same fold -----------------------#
	open SAMEFOLD, ">", $directory."samefold.list";
	open SAMEFOLD_CATH, ">", $directory."samefold_cath.list";
	open SAMEFOLD_SCOP, ">", $directory."samefold_scop.list";
	open SAMEFOLD_MIXED, ">", $directory."samefold_mixed.list";
	foreach my $nodes (keys %fold_status) {
		if ( $status_Cluster{$nodes}) {}
		else {
			print SAMEFOLD $nodes."\t";
			print SAMEFOLD $fold_status{$nodes}."\t"; 

			if ($fold_status{$nodes} eq "MixedHom") {print SAMEFOLD_MIXED $nodes."\t".$fold_status{$nodes}."\n";}
			if ($fold_status{$nodes} eq "CathHom") {print SAMEFOLD_CATH $nodes."\t".$fold_status{$nodes}."\n";}
			if ($fold_status{$nodes} eq "ScopHom") {print SAMEFOLD_SCOP $nodes."\t".$fold_status{$nodes}."\n";}

			if ($homology_status{$nodes}) {
				print SAMEFOLD "homolog	 "."\t";
			}
			else {print SAMEFOLD "non-homolog"."\t";}

			if ($status_Cluster{$nodes}) {
				print SAMEFOLD "chopping\t";
			}
			else {print SAMEFOLD "--------\t";}

			if ($complex_case{$nodes}) {
				print SAMEFOLD "complex case\t";
			}
			else {
				if ( $onetype{$nodes}) {print SAMEFOLD $onetype{$nodes}."	 \t";}
				else {print SAMEFOLD "------------\t";}
			}
			if ($lone_mda_status{$nodes}) {print SAMEFOLD "loneMDA\t";}
			else {print SAMEFOLD "-------\t";}
			if ($lone_status{$nodes}) {print SAMEFOLD "loneChain\t";}
			else {print SAMEFOLD "---------\t";}
			if ( $one_instance{$nodes}) {print SAMEFOLD "one instance\t";}
			else {print SAMEFOLD "------------\t";}
			print SAMEFOLD "\n";
		}

	}
	#-------------------------Start printing same fold -----------------------#

	#------------------------Start printing class4 --------------------------#
	open CLASS4, ">", $directory."class4.list";
	open CLASS4_CHOP_ONLY, ">", $directory."class4_chop.list";
	open CLASS4_HOMO_ONLY, ">", $directory."class4_homo.list";
	open CLASS4_HOMO_CHOP, ">", $directory."class4_chop_homo.list";
	open CLASS4_FOLD, ">", $directory."class4_samefold.list";
	foreach my $nodes (keys %class4_status) {
	  if (! $complex_case{$nodes} && ! $lone_mda_status{$nodes} && ! $one_instance{$nodes}) {
			print CLASS4 $nodes."\n";

			if (! $homology_status{$nodes}) {
				print CLASS4_CHOP_ONLY $nodes."\n";
			}
			if (! $status_Cluster{$nodes}) {
				print CLASS4_HOMO_ONLY $nodes."\n";
			}
			if ( $homology_status{$nodes} && $status_Cluster{$nodes}) {
				print CLASS4_HOMO_CHOP $nodes."\n";
			}
			if ( $fold_status{$nodes}) {
				print CLASS4_FOLD $nodes."\n";
			}
	  }
	}
	#------------------------End printing class4 ---------------------------#

	#-------------------PRINT_COMPARE_JULIETTE: lone MDA -------------------#

	open JUL_LONEMDA, ">", $directory."Jul_splitequivalents.list";
	open JUL_CLASS4, ">", $directory."Jul_class4.list";
	open JUL_CHOPHOMO, ">", $directory."Jul_chophomo.list";
	open JUL_CHOPONLY, ">", $directory."Jul_choponly.list";
	foreach my $nodes (keys %status_Cluster) {
		if ( $lone_mda_status{$nodes}) {
			print JUL_LONEMDA $nodes."\n";
		}
		elsif ( $class4_status{$nodes}) {
			print JUL_CLASS4 $nodes."\n";
		}
		elsif ( $homology_status{$nodes}) {
			print JUL_CHOPHOMO $nodes."\n";
		}
		else {
			print JUL_CHOPONLY $nodes."\n";
		}
	}

	foreach my $nodes (keys %homology_status) {
		if ( $fold_status{$nodes}) {
		#print JUL_SAMEFOLD $nodes."\n";
		}
	}
	#-------------------PRINT_COMPARE_JULIETTE: lone MDA -------------------#


	#--------------------------Start Print End Stats -------------------------#
	# At chain level:
	# $status_Chain{$uniq_chain} = CathChop/ScopChop/MixedChop
	# At cluster level:
	# @{$status_chop{$cluster_node}} = addition of $status_Chain for that cluster
	print "1) Basic Chopping: $counter_Cluster (BasicChop.list)\n";	
	print "		  Complex (Mixed): $complex_case\n		  Simpler (CathChop/ScopChop only): $OneType_case (onetype.list)\n";
	print "				  CathChop only: $basic_cath_counter ($basic_minus_LoneAndOneInstance_cath_counter remaining - lone/one instance)\n";
	print "						 Chop: $basic_minus_LoneAndOneInstance_cath_CHOP_counter\n";
	print "						 Chop + homology: $basic_minus_LoneAndOneInstance_cath_CHOP_HOMO_counter\n";
	print "				  ScopChop only: $basic_scop_counter ($basic_minus_LoneAndOneInstance_scop_counter remaining - lone/one instance)\n";
	print "						 Chop: $basic_minus_LoneAndOneInstance_scop_CHOP_counter\n";
	print "						 Chop + homology: $basic_minus_LoneAndOneInstance_scop_CHOP_HOMO_counter\n";
	print "				  Note: $basic_minus_LoneAndOneInstance_cath_counter + $basic_minus_LoneAndOneInstance_scop_counter + $lone_equiv + $lone_mda_onetype + $one_instance_onetype = $OneType_case\n";						
	print "2) Out of all $OneType_case Simpler cases:\n";
	print "	  a) Lone equivalents: $lone_equiv (solo.list)\n";
	print "		  (Def: Has basic chopping but only has one chain)\n";
	print "	  b) Lone MDA (excluding lone equivalents): $lone_mda_onetype (solo_mda.list)\n";
	print "		  (Def: Has basic chopping but only has one MDA)\n";
	print "			Note: all lone equivs are lone MDA\n";
	print "			$solo_mda_comp_equiv Complete Equivalents, $solo_mda_no_equiv No equivalents\n";
	print "	  c) One instance (excluding lone MDA): $one_instance_onetype (one_instance.list)\n";
	print "		  (Def: Has only one instance of chopping)\n";
	print "				  Chop only: $one_instance_chop_cath cath, $one_instance_chop_scop scop\n";
	print "				  Chop + homology: $one_instance_chop_homo_cath cath, $one_instance_chop_homo_scop scop\n";

	my $equivalent_count = keys %equivalent;
	print "3) Clusters with only one instance of chopping: $one_instance\n";
	print "4) Clusters with only one MDA: $one_instance_mda\n";
	# print "4) Clusters with equivalent split: $equivalent_count (equivalentsplit.list)\n";
	# print "				  $equivalent_com_count complete equivs\n";
	# print "				  $equivalent_no_count no equivs\n";
	# print "					  $equivalent_no_count_cath CathChop only (equivalentsplit_cath.list): $equivalent_no_count_cath_chop chop, $equivalent_no_count_cath_chop_homo chop+homo\n";
	# print "					  $equivalent_no_count_scop ScopChop only (equivalentsplit_scop.list): $equivalent_no_count_scop_chop chop, $equivalent_no_count_scop_chop_homo chop+homo\n";
	# print "					  $equivalent_no_count_complex Mixed/Complex\n";

	# #--------------------------End Print End Stats -------------------------#
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

sub writeInFileIfDefined{
	my ($directory, $filename, $datalist, $fold_status) = @_;

	open FILE, ">", $directory.$filename || die print "can't open file $directory$filename";

	foreach my $data (keys %{$datalist}) {
		if ( $fold_status->{$data}) {
			print FILE $data."\n";
		}		
	}
	close FILE;
	
}

sub writeInFile{
	my ($directory, $filename, $datalist) = @_;

	open FILE, ">", $directory.$filename || die print "can't open file $directory$filename";

	foreach my $data (keys %{$datalist}) {
		print FILE $data."\n";
	}

	close FILE;
}


# sub determineChopType{
# 	my ($uniq_chain,$node,$status_Chain,$status_chop,$seen,$counter_Cluster,$status_Cluster, $chop)= @_;

# 	my $chop_test;
# 	# $chop eq CathChop for Cath and ScopChop for Scop
# 	if($chop eq "ScopChop"){
# 		$chop_test = "CathChop";
# 	}
# 	else{
# 		$chop_test = "ScopChop";
# 	}

# 	if (! $status_Chain->{$uniq_chain}){
# 		$status_Chain->{$uniq_chain} = $chop; 
# 		push (@{$status_chop->{$node}, $chop);
# 		$counter_Chain++;
# 		if (!$seen->{$cluster}) {
# 			$status_Cluster->{$node}="Basic Chopping";
# 			$counter_Cluster++; 
# 			$seen->{$cluster} = "seen";
# 		}
# 	}
# 	elsif( $status_Chain->{$uniq_chain} && $status_Chain->{$uniq_chain} eq $chop_test){
# 		$status_Chain->{$uniq_chain} = "MixedChop"; 
# 		push (@{$status_chop->{$node}}, "MixedChop");
# 	}

# 	return ($status_Chain,$status_chop,$seen,$counter_Cluster,$status_Cluster, $counter_Chain);
# }

1;