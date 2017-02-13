#!/ebi/msd/swbin/perl

#######################################################################################
# @author T. Paysan-Lafosse
# @brief This script get all the CATH entries that are not integrated into InterPro signatures and present in equivalent split
#######################################################################################

use strict;
use warnings;

use DBI;


# information that we need to specify to connect to the IPPRO database

my $user_ippro = "OPS\$typhaine";                            # we connect as a particular user
my $passwd_ippro = "typhaine55";       
my $dbname_ippro = "ippro";

# connect to the database
my $ippro_dbh = DBI->connect("dbi:Oracle:$dbname_ippro", $user_ippro, $passwd_ippro);

my $path="/nfs/msd/work2/typhaine/genome3d/";
my $mdaDirectory = $path."MDA_results/CATH_4_1/";
my $equivalentFile = $mdaDirectory."equivalentsplit.list";

my $get_unintegrated = $ippro_dbh->prepare(" select
    distinct(m.method_ac)
    from interpro.method m
    left outer join interpro.mv_method_match\@iprel was on (m.method_ac= was.method_ac)
    left outer join interpro.entry2method em on (m.method_ac=em.method_ac)
    left outer join interpro.entry e on (e.entry_ac=em.entry_ac)
    where m.dbcode like 'X' and 1=1 and 1=1 and 1=1 and m.method_ac=? and e.entry_ac is null");

open EQUIV, $equivalentFile;

while (my $line = <EQUIV>) {
	chomp ($line); 
	my @code = split('\t',$line);

	my $cath = "G3DSA:".$code[0];

	$get_unintegrated->execute($cath) or die;

	while (my $row_ippro = $get_unintegrated->fetchrow_hashref){
		if($row_ippro->{METHOD_AC}){
			print "$cath\n";
		}
	}

}

close EQUIV;
