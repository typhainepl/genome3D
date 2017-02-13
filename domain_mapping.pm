package domain_mapping;
 
#######################################################################################
# @author N. Nadzirin, T. Paysan-Lafosse
# @brief
# This script generates segment_scop_cath table by combining SCOP and CATH sequences based on entry_id, and auth_asym_id
# and generates PDBE_all_domain_mapping table
# Hard-coded: segment tables & segment_scop_cath 
#######################################################################################

use strict;
use warnings; 
use DBI;


# mapping
sub mapping{
	my ($pdbe_dbh, $segment_scop_db, $segment_cath_db, $combined_segment_db, $domain_mapping_db) = @_;

	my %data;
	my (%length_Cath, %length_Scop, %length_CathMapped, %length_ScopMapped);

	print "Calculate domain mapping\n";

	# get full length_Cath
	my $segment_cath = $pdbe_dbh->prepare("select distinct * from $segment_cath_db");
	$segment_cath->execute();

	while ( my $xref_row = $segment_cath->fetchrow_hashref ) {
		my $CD = $xref_row->{CATH_DOMAIN};
		my $SiftsLength = $xref_row->{SIFTS_LENGTH};
		if (!defined $length_Cath{$CD}) {$length_Cath{$CD} = $SiftsLength;}
		else {$length_Cath{$CD} = $length_Cath{$CD} + $SiftsLength; }
	}
	# end get full length_Cath

	# get full length_Scop
	my $segment_scop = $pdbe_dbh->prepare("select distinct * from $segment_scop_db");
	$segment_scop->execute();

	while ( my $xref_row = $segment_scop->fetchrow_hashref ) {
		my $SI = $xref_row->{SCOP_ID};
		my $SiftsLength = $xref_row->{SIFTS_LENGTH};
	 	if (!defined $length_Scop{$SI}) {$length_Scop{$SI} = $SiftsLength;}
	 	else {$length_Scop{$SI} = $length_Scop{$SI} + $SiftsLength; }
	}
	# end get full length_Scop

	# select data from segment_cath_scop
	my $seq_table = $pdbe_dbh->prepare("select distinct * from $combined_segment_db");
	$seq_table->execute();

	while ( my $xref_row = $seq_table->fetchrow_hashref ) {

		my $CathOrd = $xref_row->{CATH_DOMAIN}."-".$xref_row->{CATH_ORDINAL};
		my $ScopOrd = $xref_row->{SCOP_ID}."-".$xref_row->{SCOP_ORDINAL};
		my $key = $CathOrd.$ScopOrd;

		$data{$key}{CD} = $xref_row->{CATH_DOMAIN};
		$data{$key}{SI} = $xref_row->{SCOP_ID};
		$data{$key}{S}  = $xref_row->{SUNID};
		$data{$key}{CO} = $xref_row->{CATH_ORDINAL};
		$data{$key}{SO} = $xref_row->{SCOP_ORDINAL};
		$data{$key}{CL} = $xref_row->{CATH_LENGTH};
		$data{$key}{SL} = $xref_row->{SCOP_LENGTH};
		$data{$key}{CATHCODE} = $xref_row->{CATHCODE};
		$data{$key}{SCCS} = $xref_row->{SCCS};

		my $CS = $data{$key}{CS} = $xref_row->{CATH_START};
	 	my $CE = $data{$key}{CE} = $xref_row->{CATH_END};
	  	my $SS = $data{$key}{SS} = $xref_row->{SCOP_START};
	 	my $SE = $data{$key}{SE} = $xref_row->{SCOP_END};

		my $OS; my $OE; my $case;

		# Case 1 
		# C:	________
		# S:	________
		#

		if ($CS==$SS && $CE==$SE) {
			$OS = $CS; $OE = $CE;
			#print "$CD\t OS = $OS\t OE = $OE\n";
			$case = 1;
		}


		# Case 2 
		# C: ________    or   ______      or  ______ 	     or  _________
		# S:    _______       __________            _______          _____
 
		#
		elsif ($CS<=$SS && $CE<=$SE && $CE>=$SS) {
			$OS = $SS; $OE = $CE;	
			$case = 2;
		}


		# Case 3 
		# C:      _______   or     ________    or   _____________
		# S: ________		     _____________        _______
		# 
		
		elsif ($CS>=$SS && $CE>=$SE && $CS<=$SE ) {
			$OS = $CS; $OE = $SE;
			$case = 3;
		}


		# Case 4 
		# C:     _____
		# S: _____________
		#
		
		elsif ($CS>$SS && $CE<$SE ) {
			$OS = $CS; $OE = $CE;
			$case = 4;
		}


		# Case 5 
		# C: _____________
		# S:     _____
		#

		elsif ($CS<$SS && $CE>$SE ) {
			$OS = $SS; $OE = $SE;
			$case = 5;
		}



		if ($OS) {
			$data{$key}{OS} = $OS;
			$data{$key}{OE} = $OE;

			my $OverlapLength = $data{$key}{OverlapLength} = $OE-$OS+1;
			$data{$key}{pc_cathOrd} = ( $OverlapLength / $data{$key}{CL} ) * 100;	   
			$data{$key}{pc_scopOrd} = ( $OverlapLength / $data{$key}{SL} ) * 100;

			# calculate mapped length
			my $Dom_Combined = $data{$key}{Dom_Combined} = $data{$key}{CD}."-".$data{$key}{SI};

			my $CathOrd_DomCombined = $CathOrd.$Dom_Combined;
			my $ScopOrd_DomCombined = $ScopOrd.$Dom_Combined;

			#cath
			if (!defined $length_CathMapped{$Dom_Combined}) { 
				$length_CathMapped{$Dom_Combined} = $OverlapLength; 
			}
			else { 
				$length_CathMapped{$Dom_Combined} = $length_CathMapped{$Dom_Combined} + $OverlapLength; 
			}

			#scop
			if (!defined $length_ScopMapped{$Dom_Combined}) { 
				$length_ScopMapped{$Dom_Combined} = $OverlapLength; 
			}
			else { 
				$length_ScopMapped{$Dom_Combined} = $length_ScopMapped{$Dom_Combined} + $OverlapLength; 
			}
			# end calculate mapped length
		}
		else{
			delete $data{$key};
		}

	}

	#get data from the table just created and insertion in PDBE_ALL_DOMAIN_MAPPING_NEW
	print "insert data in the $domain_mapping_db table\n";

	#insert into PDBE_ALL_DOMAIN_MAPPING request
	my $insert_request = <<"SQL";
INSERT INTO $domain_mapping_db (
	cath_domain,scop_id,sunid,cath_ordinal,scop_ordinal,cath_length,scop_length,overlap_length,pc_cath,pc_scop,pc_cath_domain,pc_scop_domain,
	pc_smaller,pc_bigger,cathcode,sccs
	) 
	values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
SQL

	my $sth_insert = $pdbe_dbh->prepare($insert_request) or die "ERR prepare insertion\n";


	foreach my $key (keys %data){

	 	my $Dom_Combined = $data{$key}{Dom_Combined};

		my $pc_cathDom = ($length_CathMapped{$Dom_Combined}/$length_Cath{$data{$key}{CD}})*100;
		my $pc_scopDom = ($length_ScopMapped{$Dom_Combined}/$length_Scop{$data{$key}{SI}})*100;
		
		my ($pc_smaller,$pc_bigger);

		if ($length_Cath{$data{$key}{CD}}<$length_Scop{$data{$key}{SI}}) {
			$pc_smaller = $pc_cathDom;
			$pc_bigger  = $pc_scopDom;
		}

		elsif ($length_Scop{$data{$key}{SI}}<$length_Cath{$data{$key}{CD}}) {
			$pc_smaller = $pc_scopDom;
			$pc_bigger  = $pc_cathDom;
		}
		elsif ($length_Scop{$data{$key}{SI}} eq $length_Cath{$data{$key}{CD}}) {
			$pc_smaller = $pc_scopDom;
			$pc_bigger  = $pc_cathDom;
		}

		#insert data in the table
		$sth_insert->execute(
			$data{$key}{CD},
			$data{$key}{SI},
			$data{$key}{S},
			$data{$key}{CO},
			$data{$key}{SO},
			$data{$key}{CL},
			$data{$key}{SL},
			$data{$key}{OverlapLength},
			$data{$key}{pc_cathOrd},
			$data{$key}{pc_scopOrd},
			$pc_cathDom,
			$pc_scopDom,
			$pc_smaller,
			$pc_bigger,
			$data{$key}{CATHCODE},
			$data{$key}{SCCS}
		); 
	}
}

1;