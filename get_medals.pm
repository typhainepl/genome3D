package get_medals;

#######################################################################################
# @author T. Paysan-Lafosse
# @brief This script counts and prints medals scores
#######################################################################################

use strict;
use warnings;

use DBI;

sub getMedals{
	my ($pdbe_dbh,$node_mapping_db) = @_;

	my ($gold,$silver,$bronze,$classified,$total)=(0)x5;

	my $medal_sth = $pdbe_dbh->prepare("select * from $node_mapping_db");	
	$medal_sth->execute();


	while ( my $row = $medal_sth->fetchrow_hashref ) {
		if (defined $row->{MUTUAL_EQUIVALENCE_MEDAL}){

			my $medal = $row->{MUTUAL_EQUIVALENCE_MEDAL};

			if ($medal eq 'a'){
				$gold ++;
			}
			elsif($medal eq 'b'){
				$silver++;
			}
			elsif($medal eq 'c'){
				$bronze++;
			}
			$classified++;
		}
		$total++;
	}

	print "results of the mapping process:\n";

	print "Total superfamilies: $total\n";
	print "Classified superfamilies: $classified\n\n";

	print "number of gold standards: $gold\n";
	print "number of silver standards: $silver\n";
	print "number of bronze standards: $bronze\n";

}

1;