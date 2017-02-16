package get_segment;

#######################################################################################
# @author T. Paysan-Lafosse
# @brief This script creates and fill segment_scop, segment_cath and segment_cath_scop tables, next used to map the domains
#######################################################################################

use strict;
use warnings;
use DBI;

#database name selected by user
sub getSegmentTables{

	my ($pdbe_dbh,$database) = @_;

	my (%count_start, %count_end);
	my ($EntryId, $AuthAsymId, $residue_id, $sql, $request, $residue);
	my @domain_ordinal;
	my (%entry, %auth,%cathCode);

	#case no database given on input
	if ($database !~ /CATH/ && $database !~ /SCOP/){
		print "error wrong database\n";
		exit;
	}

	#Recover data from SIFTS_XREF_RESIDUE
	my $domain_db;
	if($database =~ /CATH/){
		$domain_db = 'CATH_DOMAIN';
	}
	else{
		$domain_db = 'SCOP_SUNID';
	}

# select data in SIFTS_XREF_RESIDUE, except for:
#	1) unobserved residues
#	2) modified residues
#	3) MH>1
#	4) CATH_DOMAIN or SCOP_SUNID NULL

	my $xref_sql = <<"_SQL_";
SELECT
    *
FROM
    SIFTS_XREF_RESIDUE
WHERE 
OBSERVED!='N' 
AND PDB_ONE_LETTER_CODE !='X' 
AND MH_ID<=1
AND $domain_db IS NOT NULL
_SQL_

	# prepare the SQL (returns a "statement handle")
	my $xref_sth = $pdbe_dbh->prepare( $xref_sql )
	    or die "! Error: encountered an error when preparing SQL statement:\n"
	        . "ERROR: " . $pdbe_dbh->errstr . "\n"
	        . "SQL:   " . $xref_sql . "\n";
	 
	# execute the SQL
	print "select from SIFTS_XREF_RESIDUE\n";

	$xref_sth->execute
	    or die "! Error: encountered an error when executing SQL statement:\n"
	        . "ERROR: " . $xref_sth->errstr . "\n"
	        . "SQL:   " . $xref_sql . "\n";

	# go through each row
	while ( my $xref_row = $xref_sth->fetchrow_hashref ) {	

		# gather necessary columns
		my ($domain, $ordinal); 

		if($database =~ /CATH/){
			$domain   = $xref_row->{CATH_DOMAIN};
			$ordinal  = $xref_row->{CATH_ORDINAL};	
			
		}
		else{
			$domain  = $xref_row->{SCOP_SUNID};
			$ordinal = $xref_row->{SCOP_ORDINAL};
		}
		my $key = "$domain"."-"."$ordinal";

		if($database =~ /CATH/){
			$cathCode{$key} = $xref_row->{CATHCODE};
		}

		$EntryId      = $xref_row->{ENTRY_ID};
		$AuthAsymId   = $xref_row->{AUTH_ASYM_ID};
		if (!$entry{$key}) {
		   $entry{$key} = $EntryId;
		}
		if (!$auth{$key}) {
		   $auth{$key} = $AuthAsymId;
		}

		# get starting and ending of domain
		$residue_id = $xref_row->{PDB_SEQ_ID};
		if (!$count_start{$key} && !$count_end{$key}) {
			$count_start{$key} = $residue_id;
			$count_end{$key} = $residue_id;
		} 
		else {
		 	if ($residue_id < $count_start{$key}) {
				$count_start{$key} = $residue_id;
			}
			elsif ($residue_id > $count_end{$key}) {
				$count_end{$key} = $residue_id;
		   	}
		}
	}


#Add data in the table SEGMENT_x_NEW

	print "Insert data in $database\n";

	if ($database =~ /CATH/){
		$request = <<"SQL";
INSERT INTO $database (
	cath_domain,ordinal,entry_id,auth_asym_id,sifts_start,sifts_end,beg_ins_code,end_ins_code,
	sifts_length,cathcode )
	VALUES (?,?,?,?,?,?,?,?,?,?)
SQL
	}
	else{
		$request = <<"SQL";
INSERT INTO $database (
    sunid,scop_id,ordinal,entry_id,auth_asym_id,sifts_start,sifts_end,beg_ins_code,end_ins_code,
    sifts_length,sccs
    )
    VALUES (?,?,?,?,?,?,?,?,?,?,?)
SQL
	}

	my $sth_request = $pdbe_dbh->prepare($request) or die "ERR prepare insertion\n";

	foreach my $key (keys %entry) {
		@domain_ordinal = split("-",$key);

		#Get begin and end sequence positions in CATH_SEGMENT
		my %info = getInfoFromScopCath($domain_ordinal[0],$domain_ordinal[1],$pdbe_dbh,$database);
		
		#Get sift and cath/scop length
		my $sift_length = $count_end{$key} - $count_start{$key} + 1;
		

		#Insert data in the table
		if($database =~ /CATH/){
			$sth_request->execute(
				$domain_ordinal[0],
				$domain_ordinal[1],
				$entry{$key},
				$auth{$key},
				$count_start{$key},
				$count_end{$key},
				$info{BEG_INS_CODE},
				$info{END_INS_CODE},
				$sift_length,
				$cathCode{$key}
			) or die "Failed to insert data in the table\n"; 
		}
		else{
			$sth_request->execute(
				$domain_ordinal[0],
				$info{SCOP_ID},
				$domain_ordinal[1],
				$entry{$key},
				$auth{$key},
				$count_start{$key},
				$count_end{$key},
				$info{BEG_INS_CODE},
				$info{END_INS_CODE},
				$sift_length,
				$info{SCCS}
			) or die "Failed to insert data in the table\n";
		}
	}
}

sub getInfoFromScopCath{
	my ($domain, $ordinal, $pdbe_dbh, $database) = @_;
	my %info;
	my $recup_database;
	my $domain_name;

	if($database =~ /CATH/){
		$recup_database = "CATH_SEGMENT";
		$domain_name="domain";
	}
	else{
		$recup_database = "SCOP_CLASS";
		$domain_name = "sunid";
	}

	my $request = "	SELECT * FROM $recup_database WHERE $domain_name='$domain' and ordinal=$ordinal";

	my $sth_request = $pdbe_dbh->prepare($request) or die "ERR prepare selection request\n";
	$sth_request->execute or die "! Error: encountered an error when executing SQL statement:\n"
	. "ERROR: " . $sth_request->errstr . "\n"
	. "SQL:   " . $request . "\n";

	# go through each row
	while (my $xref_row = $sth_request->fetchrow_hashref){
		if (defined $xref_row->{BEG_INS_CODE}){ $info{BEG_INS_CODE}=$xref_row->{BEG_INS_CODE};}

		if (defined $xref_row->{END_INS_CODE}){ $info{END_INS_CODE}=$xref_row->{END_INS_CODE};}

		#scop database
		if (defined $xref_row->{SCOP_ID}){$info{SCOP_ID} = $xref_row->{SCOP_ID};}

		if (defined $xref_row->{SCCS}){$info{SCCS} = $xref_row->{SCCS};}

	 }
	 return %info;
}

# create table SEGMENT_CATH_SCOP_NEW
sub createCombinedSegment{
	my ($pdbe_dbh, $segment_scop_db,$segment_cath_db, $combined_segment_db) = @_;

	# insert data in SEGMENT_CATH_SCOP_NEW
	print "insert data from CATH and SCOP\n";

	my $select = <<"END_SQL";
insert into $combined_segment_db(cath_domain,cath_ordinal,scop_id,sunid,scop_ordinal,auth_asym_id,entry_id,cath_start,cath_end,cath_start_ins_code,
cath_end_ins_code,scop_start,scop_end,scop_start_ins_code,scop_end_ins_code,cath_length,scop_length,cathcode,sccs)
select 
    ca.cath_domain, 
    ca.ordinal as cath_ordinal,
    s.scop_id, 
    s.sunid, 
    s.ordinal as scop_ordinal,
    ca.auth_asym_id,    
    ca.entry_id, 
    ca.sifts_start as cath_start, 
    ca.sifts_end as cath_end, 
    ca.beg_ins_code as cath_start_ins_code,
    ca.end_ins_code as cath_end_ins_code,
    s.sifts_start as scop_start,    
    s.sifts_end as scop_end, 
    s.beg_ins_code as scop_start_ins_code,
    s.end_ins_code as scop_end_ins_code,
    ca.sifts_length as cath_length, 
    s.sifts_length as scop_length, 
    ca.cathcode,
    s.sccs
from 
    $segment_cath_db ca
inner join  
    $segment_scop_db s
    on ca.entry_id=s.entry_id 
    and ca.auth_asym_id=s.auth_asym_id
END_SQL

	my $sth_select = $pdbe_dbh->prepare($select) or die "Can't prepare select data \n";
	$sth_select->execute() or die "Can't insert data \n";

}


1;