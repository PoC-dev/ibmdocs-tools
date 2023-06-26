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
#
# This is used to merge a $srcpath of BOOK files into the existing collection
#  in $dstpath, in turn updating the database tables accordingly.
#
# Assumption is that the documents in question have appropriate entries in NEWDOCSPF,
#  a table holding information from the HTML output of the local Library Server.
# Another assumption is that duplicates to already existing BOOKs have been
#  eliminated prior to our run.
#
# The fields (title, filename, released, docnbr) are automatically copied into
#  the appropriate tables IBMDOCPF, IBMDOCTYPF, and BOODLSNMPF. Hard links from
#  $srcpath to $dstpath make the BOOKs available to the library server, and the
#  documents list output, generated in a separate step.

use strict;
use warnings;
use DBI;
use POSIX qw(strftime);

# How to access the databases - Commit immediate
my $odbc_dsn      = "DBI:ODBC:Driver={iSeries Access ODBC Driver};System=Nibbler;DBQ=IBMDOCS;CMT=0";
my $odbc_user     = "myas400user";
my $odbc_password = "myas400password";

# Paths
my $srcpath = "/var/www/default/pages/newbooks";
my $dstpath = "/var/www/default/pages/ibmdocs";

# Vars
my ($odbc_dbh, $sql_list_newdoc_sth, $sql_check_olddoc_sth, $sql_check_doctyp_sth, $sql_check_dlsname_sth, $sql_insert_doctyp_sth, $sql_insert_doc_sth, $sql_insert_dlsname_sth, $sql_del_newdoc_sth);
my ($today, $sql, $count, $title, $filename, $released, $docnbr, $srcfile, $dstfile, $prior_filename);

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

$today = strftime('%Y-%m-%d', gmtime());

#---------------------------------------

# Prepare SQL statements.
$sql_list_newdoc_sth = $odbc_dbh->prepare("SELECT title, filename, released, docnbr FROM newdocspf ORDER BY docnbr, filename");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for sql_list_newdoc_sth(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$sql_check_olddoc_sth = $odbc_dbh->prepare("SELECT COUNT(*) FROM ibmdocpf WHERE docnbr=?");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for sql_check_olddoc(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$sql_check_doctyp_sth = $odbc_dbh->prepare("SELECT COUNT(*) FROM ibmdoctypf WHERE docnbr=? AND doctype=?");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for sql_check_doctyp(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$sql_check_dlsname_sth = $odbc_dbh->prepare("SELECT COUNT(*) FROM boodlsnmpf WHERE docnbr=?");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for sql_check_dlsname(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$sql_insert_doctyp_sth = $odbc_dbh->prepare("INSERT INTO ibmdoctypf (docnbr, doctype, date_added) VALUES (?, ?, ?)");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for sql_insert_doctyp(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$sql_insert_doc_sth = $odbc_dbh->prepare("INSERT INTO ibmdocpf (title, docnbr, released) VALUES (?, ?, ?)");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for sql_insert_doc(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$sql_insert_dlsname_sth = $odbc_dbh->prepare("INSERT INTO boodlsnmpf (docnbr, dlsname) VALUES (?, ?)");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for sql_insert_dlsname(), value: %s\n", $odbc_dbh->errstr);
	die;
}
$sql_del_newdoc_sth = $odbc_dbh->prepare("DELETE FROM newdocspf WHERE docnbr=? AND filename=?");
if (defined($odbc_dbh->errstr)) {
	printf("Preparation error for sql_del_newdoc(), value: %s\n", $odbc_dbh->errstr);
	die;
}

#---------------------------------------

# List and loop through database entries.
$sql_list_newdoc_sth->execute();
if (defined($odbc_dbh->errstr)) {
	printf("\tExecution error at sql_list_newdoc(): value: %s\n", $odbc_dbh->errstr);
	next;
}
while( ($title, $filename, $released, $docnbr) = $sql_list_newdoc_sth->fetchrow ) {
	# Get rid of blanks at end.
	$docnbr =~ s/\s+$//;
	$title =~ s/\s+$//;
	$filename =~ s/\s+$//;

	$srcfile = sprintf("%s/%s.boo", $srcpath, $filename);
	$dstfile = sprintf("%s/%s.boo", $dstpath, $docnbr);

	printf("Handling '%s'...\n", $docnbr);


	# Check if we have a file to work with.
	if ( ! -e $srcfile ) {
		printf("\tnot found: '%s'.\n\n", $srcfile);
		next;
	}


	# Cautiously insert a new record.
	$sql_check_doctyp_sth->execute($docnbr, "B");
	if (defined($odbc_dbh->errstr)) {
		printf("\tExecution error at sql_check_doctyp(): value: %s\n", $odbc_dbh->errstr);
		die;
	}
	($count) = $sql_check_doctyp_sth->fetchrow;

	if ( $count eq 0 ) {
		# No entry found. Create new from newdocspf.

		$sql_insert_doctyp_sth->execute($docnbr, "B", $today);
		if (defined($odbc_dbh->errstr)) {
			printf("\tExecution error at sql_insert_doctyp(), value: %s\n", $odbc_dbh->errstr);
			die;
		}
	} else {
		# This is a dupe! Document number already exists but filename is apparently different.
		printf("\tFound existing entry in ibmdoctypf for filename='%s'.\n", $filename);
		die;
	}


	# Check existing documents database for an entry of found document number:
	#  We might already have an entry for the PDF.
	$sql_check_olddoc_sth->execute($docnbr);
	if (defined($odbc_dbh->errstr)) {
		printf("\tExecution error at sql_check_olddoc(): value: %s\n", $odbc_dbh->errstr);
		die;
	}
	($count) = $sql_check_olddoc_sth->fetchrow;

	if ( $count eq 0 ) {
		# No entry found. Create new from newdocspf.

		$sql_insert_doc_sth->execute($title, $docnbr, $released);
		if (defined($odbc_dbh->errstr)) {
			printf("\tExecution error at sql_insert_doc(), value: %s\n", $odbc_dbh->errstr);
			die;
		}
	}


	# Check file name translations database for an entry of a given document number.
	$sql_check_dlsname_sth->execute($docnbr);
	if (defined($odbc_dbh->errstr)) {
		printf("\tExecution error at sql_check_dlsname(): value: %s\n", $odbc_dbh->errstr);
		die;
	}
	($count) = $sql_check_dlsname_sth->fetchrow;

	if ( $count eq 0 ) {
		# No entry found. Create new.

		$sql_insert_dlsname_sth->execute($docnbr, uc($filename));
		if (defined($odbc_dbh->errstr)) {
			printf("\tExecution error at sql_insert_dlsname(), value: %s\n", $odbc_dbh->errstr);
			die;
		}
	}


	# Entry has apparently been successfully copied, so create link, and delete entry from source table.
	$sql_del_newdoc_sth->execute($docnbr, $filename);
	if (defined($odbc_dbh->errstr)) {
		printf("\tExecution error at sql_del_newdoc(), value: %s\n", $odbc_dbh->errstr);
		die;
	}

	# Blindly remove existing file from a possible prior run, and recreate.
	if ( -e $dstfile ) {
		unlink($dstfile);
	}
	link($srcfile, $dstfile);


	# Save for next run.
	$prior_filename = $filename;


	printf("\n");
}

#---------------------------------------

# Clean up after ourselves.
if ( $sql_list_newdoc_sth ) {
	$sql_list_newdoc_sth->finish;
}
if ( $sql_check_olddoc_sth ) {
	$sql_check_olddoc_sth->finish;
}
if ( $sql_check_doctyp_sth ) {
	$sql_check_doctyp_sth->finish;
}
if ( $sql_check_dlsname_sth ) {
	$sql_check_dlsname_sth->finish;
}
if ( $sql_insert_doctyp_sth ) {
	$sql_insert_doctyp_sth->finish;
}
if ( $sql_insert_doc_sth ) {
	$sql_insert_doc_sth->finish;
}
if ( $sql_insert_dlsname_sth ) {
	$sql_insert_dlsname_sth->finish;
}
if ( $sql_del_newdoc_sth ) {
	$sql_del_newdoc_sth->finish;
}

# Close DB connection.
if ( $odbc_dbh ) {
	$odbc_dbh->disconnect;
}

#--------------------------------------------------------------------------------------------------------------
# vim:tabstop=4:shiftwidth=4:autoindent
# -EOF-
