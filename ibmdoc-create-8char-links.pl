#!/usr/bin/perl -w

# Copyright 2023 Patrik Schindler <poc@pocnet.net>
#
# This script is part of the IBM Documentation Utilities, to be found on
# https://github.com/PoC-dev/ibmdocs-tools - see there for further details.
#
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# It is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA 02111-1307 USA or get it at
# http://www.gnu.org/licenses/gpl.html

use strict;
use warnings;
use DBI;
use POSIX qw(strftime);

# How to access the databases - Commit immediate
my $odbc_dsn      = "DBI:ODBC:Driver={iSeries Access ODBC Driver};System=Nibbler;DBQ=IBMDOCS;CMT=0";
my $odbc_user     = "myas400user";
my $odbc_password = "myas400password";

# Paths
my $srcpath = "/var/www/default/pages/ibmdocs";
my $dstpath = "/var/www/default/pages/upload";

# Vars
my ($odbc_dbh, $sql_dlsname_sth);
my ($filename, $docnbr, $srcfile, $dstfile);

# Execute anytime before using <STDOUT>.
# Causes the currently selected handle to be flushed immediately and after every print.
$| = 1;

#--------------------------------------------------------------------------------------------------------------
# Connect, etc.

$odbc_dbh = DBI->connect($odbc_dsn, $odbc_user, $odbc_password, {PrintError => 1});
if ( ! $odbc_dbh ) {
	my $dbhError="Error: Connect failed:\n";
	if (defined($DBI::err))    { $dbhError=$dbhError . $DBI::err . "\n"; }
	if (defined($DBI::errstr)) { $dbhError=$dbhError . $DBI::errstr . "\n"; }
	if (defined($DBI::state))  { $dbhError=$dbhError . $DBI::state; }
	printf("%s\n");
	die;
}

#---------------------------------------

# Prepare SQL statements.
$sql_dlsname_sth = $odbc_dbh->prepare("SELECT docnbr, dlsname FROM ibmdoctypf WHERE doctyp='B'");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for sql_dlsname(), value: %s\n", $odbc_dbh->errstr);
	die;
}

#---------------------------------------

# List and loop through database entries.
$sql_dlsname_sth->execute();
if (defined($odbc_dbh->errstr)) {
	printf("\tExecution error at sql_dlsname_sth(): value: %s\n", $odbc_dbh->errstr);
	next;
}
while( ($docnbr, $filename) = $sql_dlsname_sth->fetchrow ) {
	# Get rid of blanks at end.
	$docnbr =~ s/\s+$//;
	$filename =~ s/\s+$//;

	# Format complete name.
	$srcfile = sprintf("%s/%s.boo", $srcpath, $docnbr);
	$dstfile = sprintf("%s/%s.boo", $dstpath, $filename);


	printf("Handling '%s'...\n", $docnbr);

	# Check if we have a file to work with.
	if ( ! -e $srcfile ) {
		printf("\tnot found: '%s'.\n\n", $srcfile);
		next;
	}

	# Blindly remove existing file from a possible prior run, and recreate.
	if ( -e $dstfile ) {
		unlink($dstfile);
	}
	link($srcfile, $dstfile);


	printf("\n");
}

#---------------------------------------

# Clean up after ourselves.
if ( $sql_dlsname_sth ) {
	$sql_dlsname_sth->finish;
}

# Close DB connection.
if ( $odbc_dbh ) {
	$odbc_dbh->disconnect;
}

#--------------------------------------------------------------------------------------------------------------
# vim:tabstop=4:shiftwidth=4:autoindent
# -EOF-
