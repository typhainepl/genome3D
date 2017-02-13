#!/ebi/msd/swbin/perl
 
#######################################################################################

#######################################################################################

use strict;
use warnings;
 
use DBI;
 
# information that we need to specify to connect to the database

my $user = "nurul";                            # we connect as a particular user
my $passwd = "nurul55";                            # with a password
my $dbname = "pdbe_main_staging_dev";

# connect to the database
my $pdbe_dbh = DBI->connect("dbi:Oracle:$dbname", $user, $passwd);

# database names
my $segment_scop_db = "a_segment_scop_s";
my $segment_cath_db = "a_segment_cath_s";
my $combined_segment_db = "a_segment_cath_scop";

# global 
my (%region, %SF, %domain, %chain);

#-------------Start: Segment_scop---------#
my $scop_sth = $pdbe_dbh->prepare("select * from $segment_scop_db");
$scop_sth->execute();

while ( my $xref_row = $scop_sth->fetchrow_hashref ) {
	my $ScopID = $xref_row->{SCOP_ID};
	my $SiftsStart = $xref_row->{SIFTS_START};
	my $SiftsEnd = $xref_row->{SIFTS_END};

	my $EntryID = $xref_row->{ENTRY_ID};
	my $ChainID = $xref_row->{AUTH_ASYM_ID};
	my $key = $EntryID.$ChainID;

	my $region = $key."::".$SiftsStart."-".$SiftsEnd;
	my $SCCS = $xref_row->{SCCS};
	my $ScopNode;
	if ($SCCS =~ /(.+\..+\..+)\..+/) {$ScopNode = $1;}
	push (@{$region{$ScopID}}, $region);
	$SF{$ScopID} = $ScopNode;
	#print $ScopID."\t".$ScopNode."\n";

	push (@{$domain{$key}},$ScopID);
	push (@{$chain{$ScopNode}},$key);
	
}
#-------------End: Segment_scop---------#

#-------------Start: Segment_cath---------#
my $cath_sth = $pdbe_dbh->prepare("select * from $segment_cath_db");
$cath_sth->execute();

while ( my $xref_row = $cath_sth->fetchrow_hashref ) {
	my $CathID = $xref_row->{CATH_DOMAIN};
	my $SiftsStart = $xref_row->{SIFTS_START};
	my $SiftsEnd = $xref_row->{SIFTS_END};
	my ($EntryID,$ChainID);
	if ($CathID =~ /(....)(.).{2}/) {$EntryID = $1; $ChainID=$2;}
	my $key = $EntryID.$ChainID;
	my $region = $key."::".$SiftsStart."-".$SiftsEnd;
	my $CathNode = $xref_row->{CATHCODE};
	#print $CathID."\t".$CathNode."\n";
	push (@{$region{$CathID}}, $region);
	$SF{$CathID} = $CathNode;
	
	
	push (@{$domain{$key}},$CathID);
	push (@{$chain{$CathNode}},$key);
}
#-------------End: Segment_cath---------#

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}


#--------------Start: Main Program-----------#
my @repr; my %rep;
open REP, "/homes/nurul/Desktop/representative/representative_list";
while (my $line = <REP>) { chomp ($line); push (@repr,$line)}
foreach my $repr (@repr) {$rep{$repr} = "defined";}

open CLUSTER, "/homes/nurul/Desktop/redo_flanking/cluster_mycode_pdbe";
while (my $cluster = <CLUSTER>) {
	my @node = split (/\s+/,$cluster);
	
	print "\nCluster $node[0]\n";
	print "------------------------------\nNodes in cluster:\n";
	foreach my $node (@node) {print $node."\t";}
	print "\n";
	print "Chains:\n";
my @repeated_chain;
	foreach my $node (@node) {
	   
	   foreach my $chain (@{$chain{$node}}) {
		my $SFchain = $node."-".$chain;
		push (@repeated_chain, $SFchain);
	   }
	}
	my @uniq_chain = uniq(@repeated_chain);
	my %seen;
	foreach my $uniq_chain (@uniq_chain) {
	   if ($rep{$uniq_chain}) {
		my ($node, $chain) = split (/-/,$uniq_chain);
		if ($seen{$chain}) {}
		else {
		   print $chain."\t";
		   foreach my $element (@{$domain{$chain}}) {
			print $element;
			foreach my $region (@{$region{$element}}) {
			   if ($element =~ /\./) {print "($region) ";}
			   else {
				my ($descriptor,$real_region) = split (/::/,$region);
				print "($real_region) ";
			   }
			   
			}
			
		   }
		   print "\n";
		   $seen{$chain} = 'seen';
		}
	   }
	}
	print "\n";
}
#--------------End: Main Program-----------#


