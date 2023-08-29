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

# How to access the database.
my $odbc_dsn      = "DBI:ODBC:Driver={iSeries Access ODBC Driver};System=Nibbler;DBQ=IBMDOCS;CMT=0";
my $odbc_user     = "myas400user";
my $odbc_password = "myas400password";

# Paths
my $srcpath = "/var/www/default/pages/ibmdocs";
my $dstpath = "/var/www/default/pages/upload";

# Vars
my ($dbh, $sql_dlsname_sth);
my ($filename, $docnbr, $srcfile, $dstfile);

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
$sql_dlsname_sth = $dbh->prepare("SELECT docnbr, dlsname FROM ibmdoctypf WHERE doctype='B'");
if (defined($dbh->errstr)) {
    printf("SQL preparation error for sql_dlsname(): %s\n", $dbh->errstr);
    die;
}

#---------------------------------------

# List and loop through database records.
$sql_dlsname_sth->execute();
if (defined($dbh->errstr)) {
    printf("\tSQL execution error at sql_dlsname(): %s\n", $dbh->errstr);
    die;
}
while( ($docnbr, $filename) = $sql_dlsname_sth->fetchrow ) {
    if ( defined($dbh->errstr) ) {
        printf("\tSQL fetch error at sql_dlsname(): %s\n", $dbh->errstr);
        next;
    }

    # Get rid of blanks at end.
    $docnbr =~ s/\s+$//;
    $filename =~ s/\s+$//;

    # Format complete name.
    $srcfile = sprintf("%s/%s.boo", $srcpath, $docnbr);
    $dstfile = sprintf("%s/%s.boo", $dstpath, $filename);

    printf("Handling '%s'...\n", $docnbr);

    # Check if we have a file to work with.
    if ( ! -e $srcfile ) {
        printf("\tnot found: '%s', skipping.\n\n", $srcfile);
        next;
    }

    # Blindly remove existing file from a possible prior run, and recreate.
    if ( -e $dstfile ) {
        unlink($dstfile);
    }
    link($srcfile, $dstfile);


    printf("\n");
}

#-------------------------------------------------------------------------------

# Clean up after ourselves.
if ( $sql_dlsname_sth ) {
    $sql_dlsname_sth->finish;
}

# Close DB connection.
if ( $dbh ) {
    $dbh->disconnect;
}

#-----------------------------------------------------------------------------------------------------------------------------------
# vim: tabstop=4 shiftwidth=4 autoindent colorcolumn=133 expandtab textwidth=132
# -EOF-
