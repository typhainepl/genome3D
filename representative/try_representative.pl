#!/ebi/msd/swbin/perl

################################################################ 
#   ~30s to execute
#   This script try_representative.pl chooses the representative chains
#   within a superfamily.
#   Reason each representative is chosen is in representative_reason
################################################################ 


#use strict;
use warnings;
 
use DBI;
# information that we need to specify to connect to the database

my $user = "nurul";                            # we connect as a particular user
my $passwd = "nurul55";                            # with a password
my $dbname = "pdbe_test";

# connect to the database
my $pdbe_dbh = DBI->connect("dbi:Oracle:$dbname", $user, $passwd);

my $mapping_table = $pdbe_dbh->prepare("select * from n_pdbe_all_domain_mapping_sf");
$mapping_table->execute();

my ($key, %overlap, %multi_chain, %MultiChain_link, %MultiChain_member);
while ( my $xref_row = $mapping_table->fetchrow_hashref ) {

   my $cath_domain = $xref_row->{CATH_DOMAIN};
   my $scop_id =  $xref_row->{SCOP_ID}; 
   my $overlap_residue = $xref_row->{OVERLAP_LENGTH}; 
   my ($entry_id, $chain_id);
   if ($cath_domain =~ /(....)(.).{2}/) {$entry_id = $1; $chain_id=$2;}
   # note: on sql:
   # select distinct substr(cath_domain,1,4), substr(cath_domain,5,1) from a_pdbe_all_domain_mapping_s_
   #print $entry_id."\t".$chain_id."\n";

   $key = $entry_id.$chain_id;
   my $cathcode = $xref_row->{CATHCODE};
   my $SFchain_cath = $cathcode."-".$key;
   
   my $SFchain_scop;
   my $sccs = $xref_row->{SCCS};
   if ($sccs =~ /(.+\..+\..+)\..+/) {
		$SFchain_scop = $1."-".$key;
   }

   if (!defined $overlap{$SFchain_cath}) {$overlap{$SFchain_cath} = $overlap_residue}
   else {$overlap{$SFchain_cath} = $overlap{$SFchain_cath} + $overlap_residue}
   if (!defined $overlap{$SFchain_scop}) {$overlap{$SFchain_scop} = $overlap_residue}
   else {$overlap{$SFchain_scop} = $overlap{$SFchain_scop} + $overlap_residue}

   #else {$multi_chain{$key} = "no";}
}

# get cathscop
my $cath_table = $pdbe_dbh->prepare("select * from a_segment_cath_s");
$cath_table->execute();

my (%cathscop, %seen, %chain);
my (%cath, %scop);
while ( my $xref_row = $cath_table->fetchrow_hashref ) {
	my $cath_domain = $xref_row->{CATH_DOMAIN};
	my ($entry_id, $chain_id);
	if ($cath_domain =~ /(....)(.).{2}/) {$entry_id = $1; $chain_id=$2;}

	$key = $entry_id.$chain_id;

	my $cathcode = $xref_row->{CATHCODE};
	my $SFkey = $cathcode."-".$entry_id;
	my $SFchain = $cathcode."-".$key;
	if (defined $seen{$cath_domain}) {}
	else {
		push (@{$cathscop{$SFchain}}, $cath_domain);
		push (@{$cath{$SFchain}}, $cath_domain);
		$seen{$cath_domain} = "seen";
	}	

	if (defined $seen{$SFchain}) {}
	else {
		push (@{$chain{$SFkey}}, $SFchain);
		$seen{$SFchain} = "seen";
	}
}


# get cathscop
my $scop_table = $pdbe_dbh->prepare("select * from n_segment_scop_s");
$scop_table->execute();

while ( my $xref_row = $scop_table->fetchrow_hashref ) {
	my $scop_id = $xref_row->{SCOP_ID};
	my $entry_id = $xref_row->{ENTRY_ID};
	my $chain_id = $xref_row->{AUTH_ASYM_ID};

	$key = $entry_id.$chain_id;
	
	my $sccs = $xref_row->{SCCS};
	my ($SFkey, $SFchain);
	if ($sccs =~ /(.+\..+\..+)\..+/) {
		$SFkey = $1."-".$entry_id;
		$SFchain = $1."-".$key;
	}

	if ($scop_id =~ /\./) {
	   $multi_chain{$SFchain} = "yes";
	   push (@{$MultiChain_link{$scop_id}},$SFchain);
	}

	my $ScopChain = $scop_id.$chain_id; #multi-chain
	if (defined $seen{$ScopChain}) {}
	else {
		push (@{$cathscop{$SFchain}}, $scop_id);
		push (@{$scop{$SFchain}}, $scop_id);
		$seen{$ScopChain} = "seen";
	}

	if (defined $seen{$SFchain}) {}
	else {
		push (@{$chain{$SFkey}}, $SFchain);
		$seen{$SFchain} = "seen";
	}
	
}

open MULTICHAIN, ">", "representative_multichain";
foreach my $scop_id (keys %MultiChain_link) {
 foreach my $element ($MultiChain_link{$scop_id}) {
   print MULTICHAIN "Scop_id $scop_id: \t";
   my @MultiChain_array = @$element;
   my $length = @MultiChain_array;
   for (my $i=0;$i<$length;$i++) {
     print MULTICHAIN $MultiChain_array[$i]."\t";
     for (my $j=0;$j<$i;$j++) {
	push (@{$MultiChain_member{$MultiChain_array[$i]}}, $MultiChain_array[$j]);
     }
     for (my $k=$i+1;$k<$length;$k++) {
	push (@{$MultiChain_member{$MultiChain_array[$i]}}, $MultiChain_array[$k]);
     }
   }
   print MULTICHAIN "\n";
 }
}

print MULTICHAIN "---------------------------------";

foreach my $leader (keys %MultiChain_member) {
	print MULTICHAIN "For ".$leader." = ";
	foreach my $element ($MultiChain_member{$leader}) {
	    my @member = @$element;
	    foreach my $member (@member) {
	    	print MULTICHAIN $member."\t";
	    }
	}
	print MULTICHAIN "\n";
}



open SCOPCATH, ">", "representative_cathscop";
foreach $key (sort keys %cathscop) {
	print SCOPCATH $key."\t";
	foreach my $element (@{$cathscop{$key}}) {
		print SCOPCATH $element."\t";
	};
	print SCOPCATH "\n";
}

open MAPPED, ">", "representative_mapped";
foreach $key (sort keys %cathscop) {
	print MAPPED $key."\t";
	if (defined $overlap{$key}) {print MAPPED $overlap{$key}."\n";}
	else {$overlap{$key} = 0; print MAPPED $overlap{$key}."\n";}
}


open CHAIN, ">", "representative_chain";
foreach my $entry_id (sort keys %chain) {
	print CHAIN $entry_id."\t";
	foreach my $element (@{$chain{$entry_id}}) {
		print CHAIN $element."\t";
	};
	print CHAIN "\n";
}

#select distinct cath.entry_id, scop.entry_id from
#a_segment_cath_s cath
#full join
#a_segment_scop_s scop
#on cath.entry_id=scop.entry_id;

open REASON, ">", "representative_reason";
open FINAL, ">", "representative_list";
open FINALCHAIN, ">", "representative_list_chain";
foreach my $node_entryid (sort keys %chain) {
  
  print REASON $node_entryid."\n---------------------\n";
  my $PreviousChain;
  foreach my $CurrentChain (@{$chain{$node_entryid}}) {
     if (!defined $PreviousChain) {$PreviousChain = $CurrentChain;}
     else {
	#print "Compare $PreviousChain & $CurrentChain\n";
	if (defined $cath{$CurrentChain} && !defined $cath{$PreviousChain}) { 
	   print REASON "$PreviousChain vs $CurrentChain = $CurrentChain (Cath)\n";
	   $PreviousChain=$CurrentChain;
	}
	elsif (defined $cath{$PreviousChain} && !defined $cath{$CurrentChain}) {
	   print REASON "$PreviousChain vs $CurrentChain = $PreviousChain (Cath) \n";
	   $PreviousChain=$PreviousChain;
	}
	elsif (defined $scop{$CurrentChain} && !defined $scop{$PreviousChain}) {
	   print REASON "$PreviousChain vs $CurrentChain = $CurrentChain (Scop) \n";
	   $PreviousChain=$CurrentChain;
	}
	elsif (defined $scop{$PreviousChain} && !defined $scop{$CurrentChain}) {
	   print REASON "$PreviousChain vs $CurrentChain = $PreviousChain (Scop) \n";
	   $PreviousChain=$PreviousChain;
	}
	elsif (defined $multi_chain{$CurrentChain} && !defined $multi_chain{$PreviousChain}) {
	   print REASON "$PreviousChain vs $CurrentChain = $CurrentChain (multi-chain) \n";
	   $PreviousChain=$CurrentChain;
	}
	elsif (defined $multi_chain{$PreviousChain} && !defined $multi_chain{$CurrentChain}) {
	   print REASON "$PreviousChain vs $CurrentChain = $PreviousChain (multi-chain) \n";
	   $PreviousChain=$PreviousChain;
	}
	elsif ($overlap{$CurrentChain} > $overlap{$PreviousChain}) {
	   print REASON "$PreviousChain vs $CurrentChain = $CurrentChain (mapped_res) \n";
	   $PreviousChain=$CurrentChain;

	}	
	elsif ($overlap{$PreviousChain} > $overlap{$CurrentChain}) {
	   print REASON "$PreviousChain vs $CurrentChain = $PreviousChain (mapped_res) \n";
	   $PreviousChain=$PreviousChain;

	}
	else {
	   my @array = ($PreviousChain,$CurrentChain); @array = sort @array;
	   print REASON "$PreviousChain vs $CurrentChain = $array[0] (chain_id) \n";
	   $PreviousChain=$array[0];
	   
	}		
     }
    ##print $CurrentChain."\t";
   };
	
	if (defined $multi_chain{$PreviousChain}) {
		print REASON "Final representative is: $PreviousChain\n";
		print FINAL $PreviousChain."\n";
                if ($PreviousChain =~ /.+-(.+)/) {$finalchainonly = $1}
                print FINALCHAIN $finalchainonly."\n"; 
		print REASON "Multi-linked with: ";
		foreach my $element (@{$MultiChain_member{$PreviousChain}}) {
	    		print REASON $element."\t";
			print FINAL $element."\n";
		}
		print REASON "\n\n";
	}
	else {
		print REASON "Final representative is: $PreviousChain\n\n";
		print FINAL $PreviousChain."\n";
                if ($PreviousChain =~ /.+-(.+)/) {$finalchainonly = $1}
                print FINALCHAIN $finalchainonly."\n";
	}
 
}



















