#!/usr/bin/perl -w

# Copyright 2023, 2025 Patrik Schindler <poc@pocnet.net>
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
my ($db_doc_count, $dbh, $db_typ_count, $dirfh, $docnbr, $doctype, $errcount, $ext, $file, $num_entries, %ibmdocpf_hash,
    %ibmdoctypf_hash, $title, $today, $tmpstr, @filelist
);

# Causes the currently selected handle to be flushed immediately and after every print. Execute anytime before using <STDOUT>.
$| = 1;

$today = strftime('%Y-%m-%d', gmtime());
$errcount = 0;

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


printf("Caching database contents...\n");
my $odbc_load_docnbr_sth = $dbh->prepare("SELECT docnbr FROM ibmdocpf");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_load_docnbr_sth(): %s\n", $dbh->errstr);
    die;
}
my $odbc_load_doctype_sth = $dbh->prepare("SELECT docnbr, doctype FROM ibmdoctypf");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_load_doctype_sth(): %s\n", $dbh->errstr);
    die;
}


$odbc_load_docnbr_sth->execute;
while ( ($docnbr) = $odbc_load_docnbr_sth->fetchrow_array ) {
    $docnbr =~ s/\s+$//; # Remove trailing spaces
    $ibmdocpf_hash{$docnbr} = 1;
}

$odbc_load_doctype_sth->execute();
while ( ($docnbr, $doctype) = $odbc_load_doctype_sth->fetchrow_array ) {
    $docnbr =~ s/\s+$//;
    $doctype =~ s/\s+$//;
    $ibmdoctypf_hash{"$docnbr|$doctype"} = 1;
}


# Clean up after ourselves.
$odbc_load_docnbr_sth->finish;
$odbc_load_doctype_sth->finish;

#---------------------------------------

printf("Generate a list of directory entries...\n");
opendir($dirfh, $docpath);
@filelist = readdir($dirfh);
closedir($dirfh);
@filelist = sort(@filelist);
$num_entries = scalar(@filelist);

#-------------------------------------------------------------------------------
printf("Phase 1: Comparing directory with cached database content...\n");

# Prepare SQL statements.
my $odbc_insert_doctyp_sth = $dbh->prepare("INSERT INTO ibmdoctypf (docnbr, doctype, date_added) VALUES (?, ?, ?)");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_insert_doctyp(): %s\n", $dbh->errstr);
    die;
}
my $odbc_insert_doc_sth = $dbh->prepare("INSERT INTO ibmdocpf (docnbr) VALUES (?)");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_insert_doc(): %s\n", $dbh->errstr);
    die;
}

#---------------------------------------

# Wade through the file list and check database for an entry.
# This is sped up considerably by earlier caching the database tables locally in hashes.
foreach $file (@filelist) {
    if ( $file =~ /^(\S+)\.(pdf|boo)$/i ) {
        # Dissect filename into document number and file type.
        $docnbr = $1;
        $ext = lc($2);
        if ($ext eq 'pdf') {
            $doctype = 'P';
        } elsif ($ext eq 'boo') {
            $doctype = 'B';
        } else {
            printf("Don't know how to handle unknown file type for '%s'. Ignoring.\n", $file);
            next;
        }

        # Check local hash for ibmdoctypf entry
        unless (exists $ibmdoctypf_hash{"$docnbr|$doctype"}) {
            printf("INSERT INTO ibmdoctypf (docnbr, doctype, date_added) VALUES ('%s', '%s', '%s');\n",
                $docnbr, $doctype, $today);
            $odbc_insert_doctyp_sth->execute($docnbr, $doctype, $today);
            if (defined($dbh->errstr)) {
                printf("SQL execution error at odbc_insert_doctyp(): %s, skipping.\n", $dbh->errstr);
                $errcount++;
                next;
            }

            # Update hash to reflect new entry
            $ibmdoctypf_hash{"$docnbr|$doctype"} = 1;

            # Check local hash for ibmdocpf entry
            unless (exists $ibmdocpf_hash{$docnbr}) {
                printf("INSERT INTO ibmdocpf (docnbr) VALUES ('%s');\n", $docnbr);
                $odbc_insert_doc_sth->execute($docnbr);
                if (defined($dbh->errstr)) {
                    printf("SQL execution error at odbc_insert_doc(): %s\n", $dbh->errstr);
                    $dbh->do("rollback");
                    $errcount++;
                    next;
                }

                # Update hash to reflect new entry
                $ibmdocpf_hash{$docnbr} = 1;
            }
        }
    }
}

#---------------------------------------

# Clean up after ourselves.
if ( $odbc_insert_doctyp_sth ) {
    $odbc_insert_doctyp_sth->finish;
}
if ( $odbc_insert_doc_sth ) {
    $odbc_insert_doc_sth->finish;
}

# Handle errors gracefully.
if ( $errcount eq 0 ) {
    # Writes to the database may now commence: There were no errors.
    $dbh->do("commit");
} else {
    printf("Encountered %d errors underway. Issuing rollback() and exiting now. Please check.\n", $errcount);
    $dbh->do("rollback");
    die;
}

#-------------------------------------------------------------------------------

printf("Phase 2: Comparing cached database content to directory...\n");

my $odbc_delete_doctyp_sth = $dbh->prepare("DELETE FROM ibmdoctypf WHERE docnbr=? AND doctype=?");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for odbc_delete_doctyp(): %s\n", $dbh->errstr);
    die;
}

$errcount = 0;

#---------------------------------------

# Iterate over cached ibmdoctypf entries instead of fetching from DB.
foreach my $key (sort keys %ibmdoctypf_hash) {
    ($docnbr, $doctype) = split(/\|/, $key, 2);

    # Defensive cleanup of possible padding blanks
    if ( defined($docnbr) ) {
        $docnbr  =~ s/\s+$//;
    }
    if ( defined($doctype) ) {
        $doctype =~ s/\s+$//;
    }

    $tmpstr = sprintf("%s/%s", $docpath, $docnbr);

    if ( $doctype eq 'P' && ! -e $tmpstr . '.pdf' ) {
        printf("Found %s.pdf in DB but not in file system. Deleting entry.\n", $docnbr);
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

# Handle errors gracefully.
if ( $errcount eq 0 ) {
    # Writes to the database may now commence: There were no errors.
    $dbh->do("commit");
} else {
    printf("Encountered %d errors underway. Issuing rollback() and exiting now. Please check.\n", $errcount);
    $dbh->do("rollback");
    die;
}

#-------------------------------------------------------------------------------
# Print a list of records in ibmdocpf with no corresponding doctype.
printf("Phase 3: Checking for orphaned records in ibmdocpf (no entry in ibmdoctypf)...\n");

my $odbc_list_orphans_sth = $dbh->prepare("
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
if ( $errcount gt 0 ) {
    printf("Encountered %d errors underway. Exiting now. Please check.\n", $errcount);
    die;
}

#-------------------------------------------------------------------------------
# Print a list of records in ibmdoctypf with no corresponding doc metadata.
printf("Phase 4: Checking for orphaned records in ibmdoctypf (no entry in ibmdocpf)...\n");

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
if ( $errcount gt 0 ) {
    printf("Encountered %d errors underway. Exiting now. Please check.\n", $errcount);
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
