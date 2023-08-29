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
#
# This is used to merge a $srcpath of BOOK files into the existing collection in $dstpath, in turn updating the database tables
# accordingly.
#
# Assumption is that the documents in question have appropriate records in NEWDOCSPF, a table holding information from the HTML
# output of the local Library Server. Another assumption is that duplicates to already existing BOOKs have been eliminated prior to
# our run.
#
# The fields (title, filename, released, docnbr) are automatically copied into the appropriate tables IBMDOCPF, and IBMDOCTYPF. Hard
# links from $srcpath to $dstpath make the BOOKs available to the library server, and the documents list output, generated in a
# separate step.

use strict;
use warnings;
use DBI;
use POSIX qw(strftime);

# How to access the databases.
my $odbc_dsn      = "DBI:ODBC:Driver={iSeries Access ODBC Driver};System=Nibbler;DBQ=IBMDOCS;CMT=1";
my $odbc_user     = "myas400user";
my $odbc_password = "myas400password";

# Paths.
my $srcpath = "/var/www/default/pages/newbooks";
my $dstpath = "/var/www/default/pages/ibmdocs";

# Vars.
my ($count, $docnbr, $dstfile, $filename, $dbh, $released, $sql, $sql_check_doctyp_sth, $sql_check_olddoc_sth, $sql_del_newdoc_sth,
    $sql_insert_doc_sth, $sql_insert_doctyp_sth, $sql_list_newdoc_sth, $srcfile, $title, $today
);

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

$today = strftime('%Y-%m-%d', gmtime());

# Prepare SQL statements.
$sql_list_newdoc_sth = $dbh->prepare("SELECT title, filename, released, docnbr FROM newdocspf ORDER BY docnbr, filename");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for sql_list_newdoc_sth(): %s\n", $dbh->errstr);
    die;
}
$sql_check_olddoc_sth = $dbh->prepare("SELECT COUNT(*) FROM ibmdocpf WHERE docnbr=?");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for sql_check_olddoc(): %s\n", $dbh->errstr);
    die;
}
$sql_check_doctyp_sth = $dbh->prepare("SELECT COUNT(*) FROM ibmdoctypf WHERE docnbr=? AND doctype=?");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for sql_check_doctyp(): %s\n", $dbh->errstr);
    die;
}
$sql_insert_doctyp_sth = $dbh->prepare("INSERT INTO ibmdoctypf (docnbr, doctype, date_added, dlsname) VALUES (?, ?, ?, ?)");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for sql_insert_doctyp(): %s\n", $dbh->errstr);
    die;
}
$sql_insert_doc_sth = $dbh->prepare("INSERT INTO ibmdocpf (title, docnbr, released) VALUES (?, ?, ?)");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for sql_insert_doc(): %s\n", $dbh->errstr);
    die;
}
$sql_del_newdoc_sth = $dbh->prepare("DELETE FROM newdocspf WHERE docnbr=? AND filename=?");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for sql_del_newdoc(): %s\n", $dbh->errstr);
    die;
}

#---------------------------------------

# List and loop through database records.
$sql_list_newdoc_sth->execute();
if (defined($dbh->errstr)) {
    printf("\tSQL execution error at sql_list_newdoc(): %s\n", $dbh->errstr);
    die;
}
while( ($title, $filename, $released, $docnbr) = $sql_list_newdoc_sth->fetchrow ) {
    if ( defined($dbh->errstr) ) {
        printf("\tSQL fetch error at sql_list_newdoc(): %s\n", $dbh->errstr);
        next;
    }

    # Get rid of blanks at end.
    $docnbr =~ s/\s+$//;
    $title =~ s/\s+$//;
    $filename =~ s/\s+$//;

    $srcfile = sprintf("%s/%s.boo", $srcpath, $filename);
    $dstfile = sprintf("%s/%s.boo", $dstpath, $docnbr);

    printf("Handling '%s'...\n", $docnbr);

    # Check if we have a file to work with.
    if ( ! -e $srcfile ) {
        printf("\tnot found: '%s', not handling.\n\n", $srcfile);
        next;
    }

    #---------------

    # Cautiously insert a new record into type database.
    $sql_check_doctyp_sth->execute($docnbr, "B");
    if (defined($dbh->errstr)) {
        printf("\tSQL execution error at sql_check_doctyp(): %s\n\n", $dbh->errstr);
        next;
    }
    ($count) = $sql_check_doctyp_sth->fetchrow;
    if ( defined($dbh->errstr) ) {
        printf("\tSQL fetch error at sql_check_doctyp(): %s\n\n", $dbh->errstr);
        next;
    }

    if ( $count eq 0 ) {
        # No record found. Create new with existing data from newdocspf.

        $sql_insert_doctyp_sth->execute($docnbr, "B", $today, uc($filename));
        if (defined($dbh->errstr)) {
            printf("\tSQL execution error at sql_insert_doctyp(): %s\n\n", $dbh->errstr);
            next;
        }
    } else {
        # This is a dupe! Document number already exists as BOOK record ('B').
        printf("\tFound existing record in ibmdoctypf for filename='%s', type 'B'. Skipping.\n\n", $filename);
        next;
    }

    #---------------

    # Check existing documents database for a record of found document number: We might already have an record for a PDF.
    $sql_check_olddoc_sth->execute($docnbr);
    if (defined($dbh->errstr)) {
        printf("\tSQL execution error at sql_check_olddoc(): %s, discarding changes and skipping.\n\n", $dbh->errstr);
        $dbh->do("rollback");
        next;
    }
    ($count) = $sql_check_olddoc_sth->fetchrow;
    if ( defined($dbh->errstr) ) {
        printf("\tSQL fetch error at sql_check_olddoc_sth(): %s\n\n", $dbh->errstr);
        $dbh->do("rollback");
        next;
    }

    if ( $count eq 0 ) {
        # No record found. Create new from newdocspf.

        $sql_insert_doc_sth->execute($title, $docnbr, $released);
        if (defined($dbh->errstr)) {
            printf("\tSQL execution error at sql_insert_doc(): %s, discarding changes and skipping.\n\n", $dbh->errstr);
            $dbh->do("rollback");
            next;
        }
    }

    #---------------

    # Record data has apparently been successfully copied.

    # Blindly remove existing file from a possible prior run, and recreate.
    if ( -e $dstfile ) {
        unlink($dstfile);
    }
    link($srcfile, $dstfile);

    # Delete record from source table.
    $sql_del_newdoc_sth->execute($docnbr, $filename);
    if (defined($dbh->errstr)) {
        printf("\tSQL execution error at sql_del_newdoc(): %s, discarding changes and skipping.\n\n", $dbh->errstr);
        $dbh->do("rollback");
        next;
    }

    #---------------

    # Everything seems to be in order, commit changes for the currently handled document.
    $dbh->do("commit");
    printf("\n");
}

#-------------------------------------------------------------------------------

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
if ( $sql_insert_doctyp_sth ) {
    $sql_insert_doctyp_sth->finish;
}
if ( $sql_insert_doc_sth ) {
    $sql_insert_doc_sth->finish;
}
if ( $sql_del_newdoc_sth ) {
    $sql_del_newdoc_sth->finish;
}

# Close DB connection.
if ( $dbh ) {
    $dbh->disconnect;
}

#-----------------------------------------------------------------------------------------------------------------------------------
# vim: tabstop=4 shiftwidth=4 autoindent colorcolumn=133 expandtab textwidth=132
# -EOF-
