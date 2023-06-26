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

my ($odbc_dbh, $odbc_check_doctyp_sth, $odbc_insert_sth, $odbc_insert_doctyp_sth, $odbc_check_alltyp_sth, $odbc_check_typ_sth, $odbc_check_doc_sth, $odbc_insert_doc_sth);
my ($sql, $dirfh, @filelist, $file, $num_entries, $today, $counter, $docnbr, $doctype, $title, $db_doc_count, $db_typ_count);

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


printf("Preparing...\n");
$today = strftime('%Y-%m-%d', gmtime());


#---------------------------------------
# Get a list of directory entries into an array.

opendir($dirfh, '/var/www/default/pages/ibmdocs');
@filelist = readdir($dirfh);
closedir($dirfh);
@filelist = sort(@filelist);
$num_entries = scalar(@filelist);
$counter = 0;

#---------------------------------------
# Look if an entry in file system has an according entry in the database.

printf("Comparing Directory to Database (this takes a while)...\n");

# Prepare SQL statements.
$odbc_check_doctyp_sth = $odbc_dbh->prepare("SELECT COUNT(*) FROM ibmdoctypf WHERE docnbr=? AND doctype=?");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for odbc_check_doctyp(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$odbc_insert_doctyp_sth = $odbc_dbh->prepare("INSERT INTO ibmdoctypf (docnbr, doctype, date_added) VALUES (?, ?, ?)");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for odbc_insert_doctyp(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$odbc_check_doc_sth = $odbc_dbh->prepare("SELECT COUNT(*) FROM ibmdocpf WHERE docnbr=?");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for odbc_check_doc(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$odbc_insert_doc_sth = $odbc_dbh->prepare("INSERT INTO ibmdocpf (docnbr) VALUES (?)");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for odbc_insert_doc(), value: %s\n", $odbc_dbh->errstr);
	die;
}

foreach $file (@filelist) {
	if ( $file =~ /^(\S+)\.(pdf|boo)$/i ) {
		$counter++;
		printf("\r%d %%    ", ($counter / $num_entries * 100));

		# Dissect filename into document number, and file type.
		$docnbr = $1;
		$file =~ /^[^._]\S+\.(pdf|boo)$/i;
		if ( lc($1) eq 'pdf' ) {
			$doctype = 'P';
		} elsif ( lc($1) eq 'boo' ) {
			$doctype = 'B';
		} else {
			printf("\nDon't know how to handle unknown file type for '%s'. Ignoring.\n",
				$file);
			next;
		}

		# Check database for an entry of a given $docnbr, $doctype.
		$odbc_check_doctyp_sth->execute($docnbr, $doctype);
		if (defined($odbc_dbh->errstr)) {
			printf("\nExecution error at odbc_check_doctyp(): value: %s\n", $odbc_dbh->errstr);
			die;
		}

		# If we haven't found something, create an entry for the given document type.
		($db_typ_count) = $odbc_check_doctyp_sth->fetchrow;
		if ( $db_typ_count == 0 ) {
			# There's no entry for given doctype.
			printf("\nINSERT INTO ibmdoctypf (docnbr, doctype, date_added) VALUES ('%s', '%s', '%s');\n",
				$docnbr, $doctype, $today);
			$odbc_insert_doctyp_sth->execute($docnbr, $doctype, $today);
			if (defined($odbc_dbh->errstr)) {
				printf("\nExecution error at odbc_insert_doctyp(), value: %s\n", $odbc_dbh->errstr);
				die;
			}

			# Check if we have an entry in main table.
			$odbc_check_doc_sth->execute($docnbr);
			if (defined($odbc_dbh->errstr)) {
				printf("\nExecution error at odbc_check_doc(): value: %s\n", $odbc_dbh->errstr);
				die;
			}

			($db_doc_count) = $odbc_check_doc_sth->fetchrow;
			if ( $db_doc_count == 0 ) {
				# Insert a template entry.
				printf("\nINSERT INTO ibmdocpf (docnbr) VALUES ('%s');\n", $docnbr);
				$odbc_insert_doc_sth->execute($docnbr);
				if (defined($odbc_dbh->errstr)) {
					printf("\nExecution error at odbc_insert_doc(), value: %s\n", $odbc_dbh->errstr);
					die;
				}
			}
		}
	}
}


# Clean up after ourselves.
if ( $odbc_check_doctyp_sth ) {
	$odbc_check_doctyp_sth->finish;
}
if ( $odbc_insert_doctyp_sth ) {
	$odbc_insert_doctyp_sth->finish;
}
if ( $odbc_check_doc_sth ) {
	$odbc_check_doc_sth->finish;
}
if ( $odbc_insert_doc_sth ) {
	$odbc_insert_doc_sth->finish;
}
printf("\n");

#---------------------------------------
# See if we have a file for each database entry.

printf("Comparing Database to Directory...\n");

$odbc_check_alltyp_sth = $odbc_dbh->prepare("SELECT docnbr, doctype FROM ibmdoctypf ORDER BY docnbr, doctype");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for odbc_check_alltyp(), value: %s\n", $odbc_dbh->errstr);
	die;
}

$odbc_check_alltyp_sth->execute();
if (defined($odbc_dbh->errstr)) {
	printf("Execution error for odbc_check_alltyp(), value: %s\n", $odbc_dbh->errstr);
	die;
}


while( ($docnbr, $doctype) = $odbc_check_alltyp_sth->fetchrow) {
	# Get rid of possible padding blanks at the end.
	$docnbr =~ /^([\S]+)\s*$/;

	if ( defined($1) ) {
		if ( $doctype eq 'P' && ! -e '/var/www/default/pages/ibmdocs/' .  $1 . '.pdf' ) {
			printf("Found %s.pdf in DB but not in file system. Deleting Entry.\n", $1);
			$odbc_dbh->do("DELETE FROM ibmdoctypf WHERE docnbr='" . $1 . "' AND doctype='P'");
		} elsif ( $doctype eq 'B' && ! -e '/var/www/default/pages/ibmdocs/' .  $1 . '.boo' ) {
			printf("Found %s.boo in DB but not in file system. Deleting Entry.\n", $1);
			$odbc_dbh->do("DELETE FROM ibmdoctypf WHERE docnbr='" . $1 . "' AND doctype='B'");
		}
	}
}


# Clean up after ourselves.
if ( $odbc_check_alltyp_sth ) {
	$odbc_check_alltyp_sth->finish;
}
printf("\n");

#---------------------------------------

printf("Checking for orphaned entries in ibmdocpf (no entry in doctypf)...\n");
$odbc_check_typ_sth = $odbc_dbh->prepare("
	SELECT docnbr, title FROM ibmdocpf
	  WHERE docnbr NOT IN
	    (SELECT DISTINCT docnbr FROM ibmdoctypf)
");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for odbc_check_typ(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$odbc_check_typ_sth->execute();
if (defined($odbc_dbh->errstr)) {
	printf("Execution error for odbc_check_typ(), value: %s\n", $odbc_dbh->errstr);
	die;
}
while( ($docnbr, $title) = $odbc_check_typ_sth->fetchrow) {
	printf("'%s', title: '%s'\n",
		$docnbr, $title);
}
if ( $odbc_check_typ_sth ) {
	$odbc_check_typ_sth->finish;
}
printf("\n");

#-------------------

printf("Fixing orphaned entries in ibmdoctypf (no entry in docpf)...\n");
$odbc_check_doc_sth = $odbc_dbh->prepare("
	SELECT DISTINCT docnbr FROM ibmdoctypf
	  WHERE docnbr NOT IN
	    (SELECT docnbr FROM ibmdocpf)
");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for odbc_check_doc(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$odbc_insert_doc_sth = $odbc_dbh->prepare("INSERT INTO ibmdocpf (docnbr) VALUES (?)");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for odbc_insert_doc_sth(), value: %s\n", $odbc_dbh->errstr);
	die;
}

$odbc_check_doc_sth->execute();
if (defined($odbc_dbh->errstr)) {
	printf("Execution error for odbc_check_doc(), value: %s\n", $odbc_dbh->errstr);
	die;
}
while( ($docnbr) = $odbc_check_doc_sth->fetchrow) {
	# Get rid of eventual padding blanks at the end.
	$docnbr =~ /^([\S]+)\s*$/;
	if ( defined($1) ) {
		$docnbr = $1;

		printf("Inserting template entry for '%s'.\n", $docnbr);
		$odbc_insert_doc_sth->execute($docnbr);
		if (defined($odbc_dbh->errstr)) {
			printf("Execution error for odbc_insert_doc(), value: %s\n", $odbc_dbh->errstr);
			die;
		}
	}
}

if ( $odbc_check_doc_sth ) {
	$odbc_check_doc_sth->finish;
}
if ( $odbc_insert_doc_sth ) {
	$odbc_insert_doc_sth->finish;
}
printf("\n");

#---------------------------------------

# Close DB connection.
if ( $odbc_dbh ) {
	$odbc_dbh->disconnect;
}

#--------------------------------------------------------------------------------------------------------------
# vim:tabstop=4:shiftwidth=4:autoindent
# -EOF-
