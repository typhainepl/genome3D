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

	# get full length_Cath for each domain
	%length_Cath = getSegmentLength($pdbe_dbh,$segment_cath_db);

	# get full length_Scop for each domain
	%length_Scop = getSegmentLength($pdbe_dbh,$segment_scop_db);

	# select data from segment_cath_scop
	my $seq_table = $pdbe_dbh->prepare("select distinct * from $combined_segment_db");
	$seq_table->execute();

	while ( my $xref_row = $seq_table->fetchrow_hashref ) {

		my $CathOrd = $xref_row->{CATH_DOMAIN}."-".$xref_row->{CATH_ORDINAL};
		my $ScopOrd = $xref_row->{SCOP_DOMAIN}."-".$xref_row->{SCOP_ORDINAL};
		my $key = $CathOrd." ".$ScopOrd;

		$data{$key}{ENTRY}	  = $xref_row->{ENTRY_ID};
		$data{$key}{AUTH}	  = $xref_row->{AUTH_ASYM_ID};
		$data{$key}{CD}    	  = $xref_row->{CATH_DOMAIN};
		$data{$key}{SD}  	  = $xref_row->{SCOP_DOMAIN};
		$data{$key}{CO}   	  = $xref_row->{CATH_ORDINAL};
		$data{$key}{SO}   	  = $xref_row->{SCOP_ORDINAL};
		$data{$key}{CL} 	  = $xref_row->{CATH_LENGTH};
		$data{$key}{SL}   	  = $xref_row->{SCOP_LENGTH};
		$data{$key}{CATHCODE} = $xref_row->{CATHCODE};
		$data{$key}{SCCS}	  = $xref_row->{SCCS};
		
		if ($xref_row->{SSF}){
			$data{$key}{SSF}  = $xref_row->{SSF};
		}
		else{
			$data{$key}{SSF}  = "";
		}

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
			my $Dom_Combined = $data{$key}{Dom_Combined} = $data{$key}{CD}."-".$data{$key}{SD};

			#cath
			if (!defined $length_CathMapped{$Dom_Combined}) { 
				$length_CathMapped{$Dom_Combined} = $OverlapLength; 
			}
			else { 
				$length_CathMapped{$Dom_Combined} += $OverlapLength; 
			}

			#scop
			if (!defined $length_ScopMapped{$Dom_Combined}) { 
				$length_ScopMapped{$Dom_Combined} = $OverlapLength; 
			}
			else { 
				$length_ScopMapped{$Dom_Combined} += $OverlapLength; 
			}
			# end calculate mapped length
		}
		else{
			delete $data{$key};
		}

	}

	#get data from the table just created and insertion in PDBE_ALL_DOMAIN_MAPPING_NEW
	print "insert data in $domain_mapping_db\n";

	#insert into PDBE_ALL_DOMAIN_MAPPING request
	my $insert_request = <<"SQL";
INSERT INTO $domain_mapping_db (
	entry_id,auth_asym_id,cath_domain,scop_domain,cath_ordinal,scop_ordinal,cath_length,scop_length,overlap_length,pc_cath,pc_scop,pc_cath_domain,pc_scop_domain,
	pc_smaller,pc_bigger,cathcode,sccs,ssf
	) 
	values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
SQL

	my $sth_insert = $pdbe_dbh->prepare($insert_request) or die "ERR prepare insertion\n";


	foreach my $key (keys %data){

	 	my $Dom_Combined = $data{$key}{Dom_Combined};

		my $pc_cathDom = ($length_CathMapped{$Dom_Combined}/$length_Cath{$data{$key}{CD}})*100;
		my $pc_scopDom = ($length_ScopMapped{$Dom_Combined}/$length_Scop{$data{$key}{SD}})*100;
		
		my ($pc_smaller,$pc_bigger);

		if ($length_Cath{$data{$key}{CD}}<$length_Scop{$data{$key}{SD}}) {
			$pc_smaller = $pc_cathDom;
			$pc_bigger  = $pc_scopDom;
		}

		elsif ($length_Scop{$data{$key}{SD}}<$length_Cath{$data{$key}{CD}}) {
			$pc_smaller = $pc_scopDom;
			$pc_bigger  = $pc_cathDom;
		}
		elsif ($length_Scop{$data{$key}{SD}} eq $length_Cath{$data{$key}{CD}}) {
			$pc_smaller = $pc_scopDom;
			$pc_bigger  = $pc_cathDom;
		}

		#insert data in the table
		$sth_insert->execute(
			$data{$key}{ENTRY},
			$data{$key}{AUTH},
			$data{$key}{CD},
			$data{$key}{SD},
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
			$data{$key}{SCCS},
			$data{$key}{SSF}
		); 
	}
}
#sub getOverlapLength{
#	my ($pdbe_dbh,$lengthdb,$domain_mapping_db,$val) = @_;
#	
#		my $request_overlap = <<"SQL";
#UPDATE $lengthdb ldb
#SET ldb.pc_overlap = (SELECT sum(dm.overlap_length)
#    FROM $domain_mapping_db dm
#    where dm.entry_id = ldb.entry_id 
#    and dm.auth_asym_id=ldb.auth_asym_id 
#    and dm.$val=ldb.$val 
#    group by dm.entry_id, dm.auth_asym_id, dm.$val
#    )/ldb.length*100
#SQL
#
#	print "update overlap value in $lengthdb\n";
#	my $sth_insert = $pdbe_dbh->prepare($request_overlap) or die "Can't prepare select data \n";
#	$sth_insert->execute() or die "Can't insert data \n";
#
#}

sub getOverlapLength{
	my ($pdbe_dbh,$lengthdb,$domain_mapping_db,$val) = @_;
	
	my $request_overlap = <<"SQL";
select entry_id, auth_asym_id, $val, overlap_length
    FROM $domain_mapping_db
    order by entry_id, auth_asym_id, $val
SQL
	my $sth_get_overlap = $pdbe_dbh->prepare($request_overlap) or die "Can't prepare select data \n";
	$sth_get_overlap->execute() or die "Can't insert data \n";
	
	my %data;
	
	#calculate the total length of the overlap for each chain/superfamily
	while ( my $xref_row = $sth_get_overlap->fetchrow_hashref ) {
		my $entry_id = $xref_row->{ENTRY_ID};
		my $auth = $xref_row->{AUTH_ASYM_ID};
		my $code = $xref_row->{$val};
		my $overlap = $xref_row->{OVERLAP_LENGTH};
		
		if (!(exists $data{$entry_id}) or !(exists $data{$entry_id}{$auth}) or !(exists $data{$entry_id}{$auth}{$code})){
			$data{$entry_id}{$auth}{$code} = $overlap;
		}
		else{
			$data{$entry_id}{$auth}{$code} += $overlap;
		}
	}
	
	#insert overlap data into the lengths table
	my $request_overlap_up = <<"SQL";
	UPDATE $lengthdb ldb
SET ldb.pc_overlap = ? /ldb.length*100
where entry_id = ?
    and auth_asym_id = ?
    and $val = ?
SQL
	print "update overlap value in $lengthdb\n";
	
	foreach my $entry_id (sort keys %data){
		foreach my $auth (sort keys $data{$entry_id}){
			foreach my $code (sort keys $data{$entry_id}{$auth}){
				my $overlap = $data{$entry_id}{$auth}{$code};
				my $sth_insert = $pdbe_dbh->prepare($request_overlap_up) or die "Can't prepare select data \n";
				$sth_insert->execute($overlap,$entry_id,$auth,$code) or die "Can't insert data \n";
			}
		}
	}
}

sub getSegmentLength{
	my ($pdbe_dbh,$table) = @_;

	my %length;

	# get full length of each domain (combined ordinals)
	my $segment = $pdbe_dbh->prepare("select distinct * from $table ");
	$segment->execute();

	while ( my $xref_row = $segment->fetchrow_hashref ) {
		my $SD = $xref_row->{DOMAIN};
		my $row_length = $xref_row->{LENGTH};
	 	if (!defined $length{$SD}) {$length{$SD} = $row_length;}
	 	else {$length{$SD} = $length{$SD} + $row_length; }
	}

	return %length;
}
1;