#!/usr/bin/perl -w

# Copyright 2023 Patrik Schindler <poc@pocnet.net>
#
# This script is part of the IBM Documentation Utilities, to be found on https://github.com/PoC-dev/ibmdocs-tools - see there for
# further details.
#
# This is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or (at your option) any later version.
#
# It is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA or get it at http://www.gnu.org/licenses/gpl.html

use strict;
use warnings;
use DBI;
use POSIX qw(strftime);
use File::Copy;

# How to access the database.
my $odbc_dsn      = "DBI:ODBC:Driver={iSeries Access ODBC Driver};System=Nibbler;DBQ=IBMDOCS;CMT=0";
my $odbc_user     = "myas400user";
my $odbc_password = "myas400password";

# Paths.
my $srcpath = "/var/www/default/pages/ibmdocs";
my $dstpath = "/home/poc/pdfs-to-check";

# Vars.
my ($dbh, $docnbr, $dstfile, $sql_docnbr_sth, $srcfile);

# Causes the currently selected handle to be flushed immediately and after every print. Execute anytime before using <STDOUT>.
$| = 1;

#-----------------------------------------------------------------------------------------------------------------------------------
# Connect, etc.

printf("Connecting to database...");
$dbh = DBI->connect($odbc_dsn, $odbc_user, $odbc_password, {PrintError => 0, LongTruncOk => 1});
if ( ! defined($dbh) ) {
    printf(" failed:\n%s\n", $dbh->errstr);
    die;
} else {
    printf(" OK.\n");
}

#-------------------------------------------------------------------------------

# Prepare SQL statements.
$sql_docnbr_sth = $dbh->prepare("
	SELECT ibmdocpf.docnbr FROM ibmdocpf
	LEFT JOIN ibmdoctypf ON (ibmdocpf.docnbr = ibmdoctypf.docnbr)
	WHERE title='' AND released=1960 AND ibmdoctypf.doctype='P'
	ORDER BY ibmdocpf.docnbr
");

if (defined($dbh->errstr)) {
	printf("SQL preparation error for sql_docnbr(): %s\n", $dbh->errstr);
	die;
}

#---------------------------------------

# List and loop through database records.
$sql_docnbr_sth->execute();
if (defined($dbh->errstr)) {
	printf("\tSQL execution error at sql_docnbr(): %s\n", $dbh->errstr);
	die;
}
while( ($docnbr) = $sql_docnbr_sth->fetchrow ) {
    if ( defined($dbh->errstr) ) {
        printf("\tSQL fetch error at sql_list_newdoc(): %s\n", $dbh->errstr);
        next;
    }

	# Get rid of blanks at end.
	$docnbr =~ s/\s+$//;

	# Format complete name.
	$srcfile = sprintf("%s/%s.pdf", $srcpath, $docnbr);
	$dstfile = sprintf("%s/%s.pdf", $dstpath, $docnbr);

    #---------------

	printf("Handling '%s'...\n", $docnbr);

	# Check if we have a file to work with.
	if ( ! -e $srcfile ) {
		printf("\tnot found: '%s', skipping.\n\n", $srcfile);
		next;
	}

	# Blindly remove existing file from a possible prior run, and recreate.
	copy($srcfile, $dstfile);

	printf("\n");

    #---------------
}

#-------------------------------------------------------------------------------

# Clean up after ourselves.
if ( $sql_docnbr_sth ) {
	$sql_docnbr_sth->finish;
}

# Close DB connection.
if ( $dbh ) {
	$dbh->disconnect;
}

#-----------------------------------------------------------------------------------------------------------------------------------
# vim: tabstop=4 shiftwidth=4 autoindent colorcolumn=133 expandtab textwidth=132
# -EOF-
