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
# This is a multi-step process.
#  In step 1 we make sure the database contains ibmdoctyp records for all files in the file system.
#            In addition, we create template records in ibmdocpf for a newly found file when there is none:
#            An entry might have been created manually before. That's why we don't touch records in step 3 and 4.
#  In step 2 delete orphaned records from ibmdoctypf: No doctype leftovers from deleted files in the file system.
#  In step 3 we print out ibmdocpf records with no corresponding ibmdoctypf record.
#  In step 4 we print out ibmdoctypf records with no corresponding ibmdocpf record.
#
# The last two are to given an idea about mutual consistency. In general, ibmdocpf is meant to be maintained "by hand" (or
#  ibmdoc-merge-docs.pl), while ibmdoctypf is meant to be handled solely with this script (or ibmdoc-merge-docs.pl).
#

use strict;
use warnings;
use DBI;
use POSIX qw(strftime);

# How to access the database.
my $odbc_dsn      = "DBI:ODBC:Driver={iSeries Access ODBC Driver};System=Nibbler;DBQ=IBMDOCS;CMT=1";
my $odbc_user     = "myas400user";
my $odbc_password = "myas400password";

# Paths.
my $docpath = "/var/www/default/pages/ibmdocs";

# Vars.
my ($counter, $db_doc_count, $dbh, $db_typ_count, $dirfh, $docnbr, $doctype, $errcount, $file, $num_entries,
    $odbc_delete_doctyp_sth, $odbc_list_alltypes_sth, $odbc_check_doc_sth, $odbc_check_doctyp_sth, $odbc_list_orphans_sth,
    $odbc_insert_doc_sth, $odbc_insert_doctyp_sth, $title, $today, $tmpstr, @filelist
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
# Look if a record in file system has an according entry in the database.
printf("Comparing Directory to Database (this takes a while)...\n");

# Prepare SQL statements.
$odbc_check_doctyp_sth = $dbh->prepare("SELECT COUNT(*) FROM ibmdoctypf WHERE docnbr=? AND doctype=?");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_check_doctyp(): %s\n", $dbh->errstr);
    die;
}
$odbc_insert_doctyp_sth = $dbh->prepare("INSERT INTO ibmdoctypf (docnbr, doctype, date_added) VALUES (?, ?, ?)");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_insert_doctyp(): %s\n", $dbh->errstr);
    die;
}
$odbc_check_doc_sth = $dbh->prepare("SELECT COUNT(*) FROM ibmdocpf WHERE docnbr=?");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_check_doc(): %s\n", $dbh->errstr);
    die;
}
$odbc_insert_doc_sth = $dbh->prepare("INSERT INTO ibmdocpf (docnbr) VALUES (?)");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_insert_doc(): %s\n", $dbh->errstr);
    die;
}

$today = strftime('%Y-%m-%d', gmtime());
$counter = 0;
$errcount = 0;

#---------------------------------------
# Get a list of directory entries into an array.

opendir($dirfh, $docpath);
@filelist = readdir($dirfh);
closedir($dirfh);
@filelist = sort(@filelist);
$num_entries = scalar(@filelist);

#---------------------------------------
# Wade through the file list and check database for an entry.
# FIXME: This might be sped up considerably when caching the database tables locally.

foreach $file (@filelist) {
    if ( $file =~ /^(\S+)\.(pdf|boo)$/i ) {
        $counter++;
        printf("\r%d %%    ", ($counter / $num_entries * 100));

        # Dissect filename into document number and file type.
        $docnbr = $1;
        $file =~ /^[^._]\S+\.(pdf|boo)$/i;
        if ( lc($1) eq 'pdf' ) {
            $doctype = 'P';
        } elsif ( lc($1) eq 'boo' ) {
            $doctype = 'B';
        } else {
            printf("\nDon't know how to handle unknown file type for '%s'. Ignoring.\n\n", $file);
            next;
        }

        # Check database for an entry of a given $docnbr, $doctype.
        $odbc_check_doctyp_sth->execute($docnbr, $doctype);
        if (defined($dbh->errstr)) {
            printf("\nSQL execution error at odbc_check_doctyp(): %s, skipping.\n\n", $dbh->errstr);
            $errcount++;
            next;
        }

        # How many records have we found?
        ($db_typ_count) = $odbc_check_doctyp_sth->fetchrow;
        if (defined($dbh->errstr)) {
            printf("\nSQL fetch error at odbc_check_doctyp(): %s, skipping.\n\n", $dbh->errstr);
            $errcount++;
            next;
        }

        if ( $db_typ_count == 0 ) {
            # There's no entry for given doctype.
            printf("\nINSERT INTO ibmdoctypf (docnbr, doctype, date_added) VALUES ('%s', '%s', '%s');\n",
                $docnbr, $doctype, $today);
            $odbc_insert_doctyp_sth->execute($docnbr, $doctype, $today);
            if (defined($dbh->errstr)) {
                printf("\nSQL execution error at odbc_insert_doctyp(): %s, skipping.\n\n", $dbh->errstr);
                $errcount++;
                next;
            }

            # Check if we have a associated record in ibmdocpf.
            $odbc_check_doc_sth->execute($docnbr);
            if (defined($dbh->errstr)) {
                printf("\nSQL execution error at odbc_check_doc(): %s\n\n", $dbh->errstr);
                $dbh->do("rollback");
                $errcount++;
                next;
            }

            ($db_doc_count) = $odbc_check_doc_sth->fetchrow;
            if (defined($dbh->errstr)) {
                printf("\nSQL fetch error at odbc_check_doc(): %s\n\n", $dbh->errstr);
                $dbh->do("rollback");
                $errcount++;
                next;
            }
            if ( $db_doc_count == 0 ) {
                # Insert a template entry.
                printf("\nINSERT INTO ibmdocpf (docnbr) VALUES ('%s');\n", $docnbr);
                $odbc_insert_doc_sth->execute($docnbr);
                if (defined($dbh->errstr)) {
                    printf("\nSQL execution error at odbc_insert_doc(): %s\n\n", $dbh->errstr);
                    $dbh->do("rollback");
                    $errcount++;
                    next;
                }
            }
        }
    }
}

#---------------------------------------

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

# Handle errors gracefully.
if ( $errcount eq 0 ) {
    # Writes to the database may now commence: There were no errors.
    $dbh->do("commit");
    printf("\n");
} else {
    printf("\nEncountered %d errors underway. Issuing rollback() and exiting now. Please check.\n\n", $errcount);
    $dbh->do("rollback");
    die;
}

#-------------------------------------------------------------------------------
# See if we have a file for each database record.
printf("Comparing Database to Directory...\n");

$odbc_list_alltypes_sth = $dbh->prepare("SELECT docnbr, doctype FROM ibmdoctypf ORDER BY docnbr, doctype");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_check_alltyp(): %s\n", $dbh->errstr);
    die;
}
$odbc_delete_doctyp_sth = $dbh->prepare("DELETE FROM ibmdoctypf WHERE docnbr=? AND doctype=?");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_delete_doctyp(): %s\n", $dbh->errstr);
    die;
}

$errcount = 0;

#---------------------------------------

$odbc_list_alltypes_sth->execute();
if (defined($dbh->errstr)) {
    printf("SQL execution error for odbc_check_alltyp(): %s\n", $dbh->errstr);
    die;
}

while( ($docnbr, $doctype) = $odbc_list_alltypes_sth->fetchrow) {
    if (defined($dbh->errstr)) {
        printf("SQL fetch error for odbc_check_alltyp(): %s\n", $dbh->errstr);
        die;
    }

    # Get rid of possible padding blanks at the end.
    $docnbr =~ s/\s+$//;

    $tmpstr = sprintf("%s/%s", $docpath, $docnbr);

    if ( $doctype eq 'P' && ! -e $tmpstr . '.pdf' ) {
        printf("Found %s.pdf in DB but not in file system. Deleting entry.\n\n", $docnbr);
        $odbc_delete_doctyp_sth->execute($docnbr, 'P');
    } elsif ( $doctype eq 'B' && ! -e $tmpstr . '.boo' ) {
        printf("Found %s.boo in DB but not in file system. Deleting entry.\n", $docnbr);
        $odbc_delete_doctyp_sth->execute($docnbr, 'P');
    }
    if (defined($dbh->errstr)) {
        printf("SQL execute error for odbc_delete_doctyp(): %s\n", $dbh->errstr);
        $errcount++;
        next;
    }
}

#---------------------------------------

# Clean up after ourselves.
if ( $odbc_list_alltypes_sth ) {
    $odbc_list_alltypes_sth->finish;
}

# Handle errors gracefully.
if ( $errcount eq 0 ) {
    # Writes to the database may now commence: There were no errors.
    $dbh->do("commit");
    printf("\n");
} else {
    printf("\nEncountered %d errors underway. Issuing rollback() and exiting now. Please check.\n\n", $errcount);
    $dbh->do("rollback");
    die;
}

#-------------------------------------------------------------------------------
# Print a list of records in ibmdocpf with no corresponding doctype.
printf("Checking for orphaned records in ibmdocpf (no entry in ibmdoctypf)...\n");

$odbc_list_orphans_sth = $dbh->prepare("
    SELECT docnbr, title FROM ibmdocpf
      WHERE docnbr NOT IN
        (SELECT DISTINCT docnbr FROM ibmdoctypf)
");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_list_orphans(): %s\n", $dbh->errstr);
    die;
}

$errcount = 0;

#---------------------------------------

$odbc_list_orphans_sth->execute();
if (defined($dbh->errstr)) {
    printf("SQL execution error for odbc_list_orphans(): %s\n", $dbh->errstr);
    die;
}

while( ($docnbr, $title) = $odbc_list_orphans_sth->fetchrow) {
    if (defined($dbh->errstr)) {
        printf("SQL execution error for odbc_list_orphans(): %s\n", $dbh->errstr);
        $errcount++;
        next;
    }

    # Get rid of possible padding blanks at the end.
    $docnbr =~ s/\s+$//;
    $title =~ s/\s+$//;
    printf("\t'%s', title: '%s'\n", $docnbr, $title);
}

#---------------------------------------

# Clean up after ourselves.
if ( $odbc_list_orphans_sth ) {
    $odbc_list_orphans_sth->finish;
}

# Handle errors gracefully. No commit/rollback, because we only SELECTed records.
if ( $errcount eq 0 ) {
    printf("\n");
} else {
    printf("\nEncountered %d errors underway. Exiting now. Please check.\n\n", $errcount);
    die;
}

#-------------------------------------------------------------------------------
# Print a list of records in ibmdoctypf with no corresponding doc metadata.
printf("Checking for orphaned records in ibmdoctypf (no entry in ibmdocpf)...\n");

$odbc_list_orphans_sth = $dbh->prepare("
    SELECT DISTINCT docnbr FROM ibmdoctypf
      WHERE docnbr NOT IN
        (SELECT docnbr FROM ibmdocpf)
");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_list_orphans(): %s\n", $dbh->errstr);
    die;
}

$errcount = 0;

#---------------------------------------

$odbc_list_orphans_sth->execute();
if (defined($dbh->errstr)) {
    printf("SQL execution error for odbc_list_orphans(): %s\n", $dbh->errstr);
    die;
}

while( ($docnbr) = $odbc_list_orphans_sth->fetchrow) {
    if (defined($dbh->errstr)) {
        printf("SQL execution error for odbc_list_orphans(): %s\n", $dbh->errstr);
        $errcount++;
        next;
    }

    # Get rid of possible padding blanks at the end.
    $docnbr =~ s/\s+$//;
    printf("\t%s\n", $docnbr);
}

#---------------------------------------

# Clean up after ourselves.
if ( $odbc_list_orphans_sth ) {
    $odbc_list_orphans_sth->finish;
}

# Handle errors gracefully. No commit/rollback, because we only SELECTed records.
if ( $errcount eq 0 ) {
    printf("\n");
} else {
    printf("\nEncountered %d errors underway. Exiting now. Please check.\n\n", $errcount);
    die;
}

#-------------------------------------------------------------------------------

# Close DB connection.
if ( $dbh ) {
    $dbh->disconnect;
}

#-----------------------------------------------------------------------------------------------------------------------------------
# vim: tabstop=4 shiftwidth=4 autoindent colorcolumn=133 expandtab textwidth=132
# -EOF-
