package get_segment;

#######################################################################################
# @author T. Paysan-Lafosse
# @brief This script creates and fill segment_scop, segment_cath and segment_cath_scop tables, next used to map the domains
#######################################################################################

use strict;
use warnings;
use DBI;
use Data::Dumper;

#get data from SCOP tables
sub getSegmentScop{
	#Recover data from ENTITY_SCOP and SCOP_CLASS
	
	my ($pdbe_dbh,$database) = @_;
	my %entry;

	#case no database given on input
	if ($database !~ /SCOP/){
		print "error wrong database\n";
		exit;
	}
	
	my $get_info_scop = <<"SQL";
	insert into $database (entry_id,auth_asym_id,"START","END",length,sccs,ssf,ordinal,domain)
select e.entry_id, e.auth_asym_id, e."START", e."END", e."END"-e."START"+1 as LENGTH, s.sccs, s.superfamily_id, e.ordinal, e.scop_id as DOMAIN
from 
  sifts_admin_new.entity_scop e,
  sifts_admin_new.scop_class s
where 
  e.entry_id = s.entry and
  e.sunid = s.sunid
SQL
	
	print "insert data in $database\n";
	
	my $sth_select = $pdbe_dbh->prepare($get_info_scop) or die "Can't prepare select data \n";
	$sth_select->execute() or die "Can't insert data \n";
}

#get data from CATH tables
sub getSegmentCath{
	#Recover data from ENTITY_CATH
	my ($pdbe_dbh, $database) = @_;
	
	my %entry;
	
	#case no database given on input
	if ($database !~ /CATH/ ){
		print "error wrong database\n";
		exit;
	}
	
	my $get_info_cath = <<"SQL";
	insert into $database (entry_id,auth_asym_id,"START","END",length,cathcode,ordinal,domain)
select entry_id, auth_asym_id, "START", "END", "END"-"START"+1 as LENGTH, accession, ordinal, domain
from 
	sifts_admin_new.entity_cath
SQL
	
	print "insert data in $database\n";
	my $sth_select = $pdbe_dbh->prepare($get_info_cath) or die "Can't prepare select data \n";
	$sth_select->execute() or die "Can't insert data \n";

}

# create table SEGMENT_CATH_SCOP
sub createCombinedSegmentSCOP{
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

# create table SEGMENT_CATH_ECOD
sub createCombinedSegmentECOD{
	my ($pdbe_dbh, $segment_ecod_db,$segment_cath_db, $combined_segment_db) = @_;

	# insert data in SEGMENT_CATH_ECOD
	print "insert data from CATH and ECOD\n";

	my $select = <<"SQL";
insert into $combined_segment_db(cath_domain,cath_ordinal,scop_domain,scop_ordinal,auth_asym_id,entry_id,cath_start,cath_end,cath_length,
	scop_start,scop_end,scop_length,cathcode,sccs)
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
    s.sccs
from 
    $segment_cath_db ca
inner join  
    $segment_ecod_db s
    on ca.entry_id=s.entry_id 
    and ca.auth_asym_id=s.auth_asym_id
where s."START" is not null 
and s."END" is not null
SQL

	my $sth_select = $pdbe_dbh->prepare($select) or die "Can't prepare select data \n";
	$sth_select->execute() or die "Can't insert data \n";

}

1;