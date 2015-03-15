Perl script that reads a Trac database and converts it to CSV format that is compatible with Jira. Comments are converted to UTF-8 for compatibility with the Jira database.

The script depends on these Perl Modules:
  * [DBI](http://search.cpan.org/~timb/DBI-1.604/)
  * [Encode](http://search.cpan.org/~dankogai/Encode-2.25/)
  * [Getopt::Long](http://search.cpan.org/~jv/Getopt-Long-2.37/)

Usage: trac2jira.pl -i 

<trac\_database>

 [-o 

<output\_file>

]
  * If no output file is given, output is printed to STDOUT.

Once the CSV is created, run the import wizard and map the proper fields into Jira. You can use this link as reference:

Use '$' as the CSV delimeter.

[Jira Value Mapping](http://www.atlassian.com/software/jira/docs/latest/csv_import.html#values)

To Download:
Use SVN
  * svn checkout http://trac-to-jira-migrate.googlecode.com/svn/trunk/
OR
  * Download the latest version from the Downloads link



