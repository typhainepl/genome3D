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
	my $request;

	#case no database given on input
	if ($database !~ /CATH/ && $database !~ /SCOP/){
		print "error wrong database\n";
		exit;
	}

	#Recover data from ENTITY_CATH, CATH_SEGMENT, ENTITY_SCOP, SCOP_CLASS
	#and add data in the table SEGMENT_CATH or SEGMENT_SCOP

	print "Insert data in $database\n";

	if ($database =~ /CATH/){
		$request = <<"SQL";
INSERT INTO $database (domain,ordinal,entry_id,auth_asym_id,"START","END",length,cathcode)
select distinct
  s.domain,
  s.ordinal,
  si.entry_id,
  si.auth_asym_id,
  e."START",
  e."END",
  e."END"-e."START"+1,
  e.ACCESSION
from
  entity_cath e,
  cath_segment s,
SQL

	}
	else{
		$request = <<"SQL";
INSERT INTO $database (
    domain,ordinal,entry_id,auth_asym_id,"START","END",length,sccs,ssf)
select distinct
  s.sunid,
  s.ordinal,
  si.entry_id,
  si.auth_asym_id,
  e."START",
  e."END",
  e."END"-e."START"+1,
  s.SCCS,
  s.superfamily_id
from
  entity_scop e,
  scop_class s,
SQL
	}

	my $where="sifts_xref_residue si 
where
  e.entry_id = s.entry and
  e.auth_asym_id = s.auth_asym_id and
  e.entry_id = si.entry_id and
  e.auth_asym_id = si.auth_asym_id and
  si.pdb_seq_id in (e.\"START\", e.\"END\") and
  si.auth_seq_id in (s.beg_seq, s.end_seq) and
  ((si.auth_seq_id_ins_code in (s.beg_ins_code, s.end_ins_code)) or (si.auth_seq_id_ins_code = ' ' and (s.beg_ins_code is null or s.end_ins_code is null))) and
  si.canonical_acc = 1
  and e.entry_id='2r3y'";

	$request .= $where;
	# print $request;
	my $sth_request = $pdbe_dbh->do($request) or die "ERR request execution\n";
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