package get_segment;

#######################################################################################
# @author T. Paysan-Lafosse
# @brief This script creates and fill segment_scop, segment_cath and segment_cath_scop tables, next used to map the domains
#######################################################################################

use strict;
use warnings;
use DBI;
use Data::Dumper;

#database name selected by user
sub getSegmentScop{
	#Recover data from ENTITY_SCOP and SCOP_CLASS
	
	my ($pdbe_dbh,$database) = @_;
	my %entry;

	#case no database given on input
	if ($database !~ /SCOP/){
		print "error wrong database\n";
		exit;
	}
	
	#requests for SCOP
	my $get_nb_ordinal = <<"SQL";
select distinct entry,sunid as DOMAIN,count(ordinal) as NB_ORDINAL
from sifts_admin_new.scop_class
where (entry,sunid) in (select distinct entry_id, sunid from sifts_admin_new.entity_scop)
group by entry,sunid
SQL
		
	my $get_info_ordinal_1 = <<"SQL";
select e.auth_asym_id, e."START", e."END", e."END"-e."START"+1 as LENGTH, s.sccs, s.superfamily_id
from 
  sifts_admin_new.entity_scop e,
  sifts_admin_new.scop_class s
where 
  e.entry_id = ? and s.sunid = ?  and
  e.entry_id = s.entry and
  e.sunid = s.sunid
SQL
		
	my $get_info_ordinal_2_more = <<"SQL";
select auth_asym_id, "START", "END", "END"-"START"+1 as LENGTH, scop_domain
from sifts_admin_new.entity_scop
where sunid = ?
order by "START","END"
SQL

	my $search_ordinal = <<"SQL";
select ordinal,sccs,superfamily_id
from sifts_admin_new.SCOP_CLASS
where sunid = ? and auth_asym_id = ? 
SQL

	my $insert = <<"SQL";
INSERT INTO $database (
    domain,ordinal,entry_id,auth_asym_id,"START","END",length,sccs,ssf
    )
    VALUES (?,?,?,?,?,?,?,?,?)
SQL

	print "get scop data\n";
	
	#get the number of ordinals
	my $sth_get_nb_ordinal = $pdbe_dbh->prepare($get_nb_ordinal) or die "ERR request preparation\n";
	my $sth_get_info_ordinal_1 = $pdbe_dbh->prepare($get_info_ordinal_1) or die "ERR request preparation\n";
	my $sth_get_info_ordinal_2_more = $pdbe_dbh->prepare($get_info_ordinal_2_more) or die "ERR request preparation\n";
	
	
	$sth_get_nb_ordinal->execute() or die "ERR request execution\n";
	
	while ( my $row = $sth_get_nb_ordinal->fetchrow_hashref ) {	
		my @listpos;
		# case where only one ordinal
		if ($row->{NB_ORDINAL} == 1 ){
			#get the domain regarding the database
			my $key = $row->{DOMAIN}."-1";
			$entry{$key}{ENTRY_ID} = $row->{ENTRY};
			
			#get information in scop_class and entity_scop tables
			$sth_get_info_ordinal_1->execute($entry{$key}{ENTRY_ID},$row->{DOMAIN}) or die "ERR request execution\n";
			
			while ( my $row2 = $sth_get_info_ordinal_1->fetchrow_hashref ) {	
				$entry{$key}{AUTH} = $row2->{AUTH_ASYM_ID};
				$entry{$key}{START} = $row2->{START};
				$entry{$key}{END} = $row2->{END};
				$entry{$key}{LENGTH} = $row2->{LENGTH};
				$entry{$key}{SSF} = $row2->{SUPERFAMILY_ID};
				$entry{$key}{SCCS} = $row2->{SCCS};
			}	
		}
		#case of more than one ordinal
		else{
			#get information from entity_scop table
			$sth_get_info_ordinal_2_more->execute($row->{DOMAIN}) or die "ERR request execution\n";
	
			while ( my $row2 = $sth_get_info_ordinal_2_more->fetchrow_hashref ) {		
				my $search_ordinal_complete = $search_ordinal;
				my $scop_domain = $row2->{SCOP_DOMAIN};
				my $sunid = $row->{DOMAIN};
				my $auth = $row2->{AUTH_ASYM_ID};
	
				#get information of different positions from SCOP_DOMAIN column in entity_scop
				$scop_domain = substr($scop_domain,5);
				my @domains = split(',',$scop_domain);
	
				my $posbegin ="null";
				my $posend = "null";
	
				#remove empty domains
				my @newDomains;
				
				foreach my $dom (@domains){
					if ($dom =~ /^(.):((-?\d+)-(-?\d+))$/){
						push (@newDomains, $dom);
					}
				}
				#sort the domains
				my @sortDomains = sort { $a =~ s/(.):(-?\d+)-(-?\d+)/$2/r <=> $b =~ s/(.):(-?\d+)-(-?\d+)/$3/r } @newDomains;
				
				foreach my $dom (@sortDomains){
					if ($dom =~ /(.):((-?\d+)-(-?\d+))/){
						#get the begin and end position of SCOP_DOMAIN for the current AUTH_ASYM_ID
						if($1 eq $auth && !grep(/^$2$/,@listpos) && $posbegin eq "null" && $posend eq "null"){
							$posbegin =$3;
							$posend = $4;	
							push(@listpos,$2);
						}
					}
				}
				#complete the request to find domain and ordinal in scop_class table
				if ($posbegin eq "null"){
					$search_ordinal_complete.="and beg_seq is null and end_seq is null";
				}
				else{
					$search_ordinal_complete.="and beg_seq = $posbegin and end_seq = $posend";
				}
				#get the ordinal,sccs and superfamily_id corresponding to the domain, auth_asym_id and begin and end positions
				my $search_ordinal_sth = $pdbe_dbh->prepare($search_ordinal_complete) or die "ERR request preparation\n";
				$search_ordinal_sth->execute($sunid,$auth) or die "ERR request execution\n";
				
				while ( my $row3 = $search_ordinal_sth->fetchrow_hashref ) {
					my $key = $sunid."-".$row3->{ORDINAL};
					$entry{$key}{ENTRY_ID} = $row->{ENTRY};
					$entry{$key}{AUTH} = $auth;
					$entry{$key}{SCCS} = $row3->{SCCS};
					$entry{$key}{START} = $row2->{START};
					$entry{$key}{END} = $row2->{END};
					$entry{$key}{LENGTH} = $row2->{LENGTH};	
					$entry{$key}{SSF} = $row3->{SUPERFAMILY_ID};
				}
			}
		}
	}
	
	
	#add data to the table SEGMENT_SCOP
	print "insert data in $database\n";

	my $sth_insert = $pdbe_dbh->prepare($insert) or die "ERR prepare insertion\n";

	foreach my $key (keys %entry) {
		my @domain_ordinal = split("-",$key);
		
		#Insert data in the table
		$sth_insert->execute(
			$domain_ordinal[0],
			$domain_ordinal[1],
			$entry{$key}{ENTRY_ID},
			$entry{$key}{AUTH},
			$entry{$key}{START},
			$entry{$key}{END},
			$entry{$key}{LENGTH},
			$entry{$key}{SCCS},
			$entry{$key}{SSF}
		) or die "Failed to insert data in the table\n";
	}
}

sub getSegmentCath{
	#Recover data from ENTITY_CATH, CATH_SEGMENT
	my ($pdbe_dbh, $database) = @_;
	
	my %entry;
	
	#case no database given on input
	if ($database !~ /CATH/ ){
		print "error wrong database\n";
		exit;
	}

	my $get_info_ordinal_2_more = <<"SQL";
select distinct s.domain, e.entry_id,s.ordinal, si.auth_asym_id, e."START", e."END", e."END"-e."START"+1 as LENGTH, e.ACCESSION
from
  sifts_admin_new.entity_cath e,
  sifts_admin_new.cath_segment s,
  sifts_admin_new.sifts_xref_residue si 
where
  e.entry_id = s.entry and
  e.auth_asym_id = s.auth_asym_id and
  e.entry_id = si.entry_id and
  e.auth_asym_id = si.auth_asym_id and
  si.pdb_seq_id in (e.\"START\", e.\"END\") and
  si.auth_seq_id in (s.beg_seq, s.end_seq) and
  ((si.auth_seq_id_ins_code in (s.beg_ins_code, s.end_ins_code)) or (si.auth_seq_id_ins_code = ' ' and (s.beg_ins_code is null or s.end_ins_code is null))) and
  si.canonical_acc = 1 
SQL

	my $insert = <<"SQL";
INSERT INTO $database (
	domain,ordinal,entry_id,auth_asym_id,"START","END",length,cathcode )
	VALUES (?,?,?,?,?,?,?,?)
SQL
		
	print "get cath data\n";
	
	my $sth_get_info_ordinal_2_more = $pdbe_dbh->prepare($get_info_ordinal_2_more) or die "ERR request preparation\n";
	$sth_get_info_ordinal_2_more->execute() or die "ERR request execution\n";

	while ( my $row = $sth_get_info_ordinal_2_more->fetchrow_hashref ) {	
		my $key = $row->{DOMAIN}."-".$row->{ORDINAL};
		if (!$entry{$key}){
			$entry{$key}{ENTRY_ID} = $row->{ENTRY_ID};	
			$entry{$key}{AUTH} = $row->{AUTH_ASYM_ID};
			$entry{$key}{START} = $row->{START};
			$entry{$key}{END} = $row->{END};
			$entry{$key}{LENGTH} = $row->{LENGTH};
			$entry{$key}{CATHCODE} = $row->{ACCESSION};
		}
	}
	
	
	#add data to the table SEGMENT_CATH
	print "insert data in $database\n";

	my $sth_insert = $pdbe_dbh->prepare($insert) or die "ERR prepare insertion\n";

	foreach my $key (keys %entry) {
		my @domain_ordinal = split("-",$key);
		
		#Insert data in the table
		$sth_insert->execute(
			$domain_ordinal[0],
			$domain_ordinal[1],
			$entry{$key}{ENTRY_ID},
			$entry{$key}{AUTH},
			$entry{$key}{START},
			$entry{$key}{END},
			$entry{$key}{LENGTH},
			$entry{$key}{CATHCODE}
		) or die "Failed to insert data in the table\n"; 
	}
}

# create table SEGMENT_CATH_SCOP
sub createCombinedSegment{
	my ($pdbe_dbh, $segment_scop_db,$segment_cath_db, $combined_segment_db) = @_;

	# insert data in SEGMENT_CATH_SCOP
	print "insert data from CATH and SCOP\n";

	my $select = <<"SQL";
insert into $combined_segment_db(cath_domain,cath_ordinal,scop_domain,scop_ordinal,auth_asym_id,entry_id,cath_start,cath_end,cath_length,
	scop_start,scop_end,scop_length,cathcode,sccs,ssf)
select distinct
    ca.domain, 
    ca.ordinal as cath_ordinal,
    s.domain, 
    s.ordinal as scop_ordinal,
    ca.auth_asym_id,    
    ca.entry_id, 
    ca."START" as cath_start, 
    ca."END" as cath_end, 
    ca."LENGTH" as cath_length, 
    s."START" as scop_start,    
    s."END" as scop_end, 
    s."LENGTH" as scop_length, 
    ca.cathcode,
    s.sccs,
    s.ssf
from 
    $segment_cath_db ca
inner join  
    $segment_scop_db s
    on ca.entry_id=s.entry_id 
    and ca.auth_asym_id=s.auth_asym_id
SQL

	my $sth_select = $pdbe_dbh->prepare($select) or die "Can't prepare select data \n";
	$sth_select->execute() or die "Can't insert data \n";

}

1;