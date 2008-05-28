#!/usr/bin/perl -w
# Author: Scott Haskell
# Date: 05/28/2008
# License: GPL v3
# 
# Usage: ./trac2jira.pl -i <trac_database> [-o <output_file>]
# 
# If no output file is given, output is printed to STDOUT.
# 
# The script depends on these Perl Modules: 
# * DBI
# * Encode
# * Getopt::Long
#
# Usage: trac2jira.pl -i <trac_database> [-o <output_file>]
#  * If no output file is given, output is printed to STDOUT.
#
#Once the CSV is created, run the import wizard and map the proper fields into Jira. You can use this link as reference:
#
# Use '$' as the CSV delimeter.
# http://www.atlassian.com/software/jira/docs/latest/csv_import.html
#
use strict;
use DBI;
use Encode;
use Getopt::Long;

my ($res1, $res2);
my ($tracdb, $outfile);
my %comments;
my $debug = 0;

# Subroutine to query Trac Database
# Argument(s): None
sub query_tracdb
{
	if(!-f $tracdb) {
		die "$tracdb does not exist!\n";
	}

	my $dbh = DBI->connect("dbi:SQLite:dbname=$tracdb", "", "");
	
	$res1 = $dbh->selectall_arrayref("SELECT ticket, newvalue FROM ticket_change WHERE field = 'comment'");

	$res2 = $dbh->selectall_arrayref("SELECT id, type, component, version, time, changetime, summary, description, priority, reporter, resolution, status, keywords, milestone, owner FROM ticket");

	$dbh->disconnect();
}

# Subroutine to build hash of comments for each Trac ticket.
# Argument(s): None
sub save_comments
{
	my ($id, $i, $comment, $v);

	foreach my $v (@$res1) {
		foreach (my $i = 0; $i <  $#$v; $i++) {
			chomp($id = $v->[$i]);
			chomp($comment = $v->[$i+1]);
			encode("UTF-8", $comment);

			if($id && !$comment) {
				next();
			}
			elsif ($id && !$comments{$id}) {
				$comments{$id} = $comment;
			}
			else {
				$comments{$id} .= "\n$comment";
			}
		}
	}
}

# Subroutine to create CSV for import into Jira
# Argument(s): None
sub create_csv
{
	my $total_tickets = 0; 
	my ($id, $type, $component, $version, $time, $changetime);
	my ($summary, $descr, $priority, $reporter, $resolution);
	my ($status, $keywords, $comment, $milestone, $owner);
	my ($conv_time, $conv_changetime);

	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst);

	# open file handle and print field mapping
	if($outfile) {
		# open file handle for writing
		open(FH, '+>', $outfile) or die "can't open $outfile for writing\n";

		# Jira needs this to map fields
		print FH "ticket\$type\$component\$version\$created\$_changetime\$summary\$description\$priority\$_reporter\$resolution\$status\$keywords\$comments\$milestone\$owner\n";
	}
	else {
		print "ticket\$type\$component\$version\$created\$_changetime\$summary\$description\$priority\$_reporter\$resolution\$status\$keywords\$comments\$milestone\$owner\n";
	}

	foreach my $v (@$res2) {
		foreach (my $i = 0; $i <  $#$v; $i+=15) {
			$v->[$i] ? chomp($id = $v->[$i]) : ($id = '') ; 
			$v->[$i+1] ? chomp($type = $v->[$i+1]) : ($type = '');
			$v->[$i+2] ? chomp($component = $v->[$i+2]) : ($component = '');
			$v->[$i+3] ? chomp($version = $v->[$i+3]) : ($version = '');
			$v->[$i+4] ? chomp($time = $v->[$i+4]) : ($time = '');
			$v->[$i+5] ? chomp($changetime = $v->[$i+5]) : ($changetime = '');
			$v->[$i+6] ? chomp($summary = $v->[$i+6]) : ($summary = '');
			$v->[$i+7] ? chomp($descr = $v->[$i+7]) : ($descr = '');
			$v->[$i+8] ? chomp($priority = $v->[$i+8]) : ($priority = '');
			$v->[$i+9] ? chomp($reporter = $v->[$i+9]) : ($reporter = '');
			$v->[$i+10] ? chomp($resolution = $v->[$i+10]) : ($resolution = '');
			$v->[$i+11] ? chomp($status = $v->[$i+11]) : ($status = '');
			$v->[$i+12] ? chomp($keywords = $v->[$i+12]) : ($keywords = '');
			$v->[$i+13] ? chomp($milestone = $v->[$i+13]) : ($milestone = '');
			$v->[$i+14] ? chomp($owner= $v->[$i+14]) : ($owner= '');
			$comments{$v->[$i]} ? chomp($comment = $comments{$v->[$i]}) : ($comment = '');
			$total_tickets++;

			# convert time & changetime to yyyy/MM/dd hh:mm:ss
			($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);	
			$year += 1900;
			$conv_time = "$year/$mon/$mday $hour:$min:$sec";

			($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($changetime);
			$year += 1900;
			$conv_changetime = "$year/$mon/$mday $hour:$min:$sec";
	
			# add quotes to strings and sanitize data
			$summary =~ s/\r//g;
			$summary =~ s/"/""/g;
			$summary =~ s/^/"/;
			$summary =~ s/$/"/;

			$descr =~ s/\r//g;
			$descr =~ s/"/""/g;
			$descr =~ s/[[BR]]/\n/g;
			$descr =~ s/aaaaaa/,/g;
			$descr =~ s/^/"/;
			$descr =~ s/$/"/;

			$keywords =~ s/\r//g;
			$keywords =~ s/"/""/g;
			$keywords =~ s/^/"/;
			$keywords =~ s/$/"/;

			$comment =~ s/\r//g;
			$comment =~ s/"/""/g;
			$comment =~ s/[[BR]]/\n/g;
			$comment =~ s/aaaaaa/,/g;
			$comment =~ s/^/"/;
			$comment =~ s/$/"/;

			# strip out reporters name if in the format "user" <user@domain.com>
			# chokes when creating usernames
			if($reporter =~ /^"(.*)"\s+<.*\@.*>.*$/) {
				$reporter = $1;
			}

			# Create CSV
			# Print to File
			if($outfile) {
				print FH "$id\$"; 
				print FH "$type\$"; 
				print FH "$component\$"; 
				print FH "$version\$";
				print FH "$conv_time\$";
				print FH "$conv_changetime\$";
				print FH "$summary\$";
				print FH "$descr\$";
				print FH "$priority\$";
				print FH "$reporter\$";
				print FH "$resolution\$";
				print FH "$status\$";
				print FH "$keywords\$";
				print FH "$comment\$";
				print FH "$milestone\$";
				print FH "$owner\$\n";
			}
			# Print to STDOUT
			else {
				print "$id\$"; 
				print "$type\$"; 
				print "$component\$"; 
				print "$version\$";
				print "$conv_time\$";
				print "$conv_changetime\$";
				print "$summary\$";
				print "$descr\$";
				print "$priority\$";
				print "$reporter\$";
				print "$resolution\$";
				print "$status\$";
				print "$keywords\$";
				print "$comment\$";
				print "$milestone\$";
				print "$owner\$\n";
			}
		}
	}
	
	# close file handle
	close(FH);

	print "\n**************\n*  FINISHED  *\n**************\n";
	print "$total_tickets Issues Processed\n\n";
}

# Subroutine to get command line arguments
# Argument(s): None
sub get_args
{
    GetOptions (
       	'i=s' => \$tracdb,
		'o=s' => \$outfile,
    );

    if(!$tracdb) {
        print("Usage: ./trac2jira.pl -i <trac_database> [-o <output_file>]\n");
        exit(1);
    }
}


##
## MAIN
##
get_args();
query_tracdb();
save_comments();
create_csv();
