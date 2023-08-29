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
# This Makefile helps in porting patches from the password-less repository to the real scripts in ~/bin.

.PHONY: genpatch apypatch clean

all:
	@echo "make genpatch, edit files in /tmp, make apypatch, make clean"

genpatch: ibmdoc-copy-unhandled-pdfs.pl ibmdoc-create-8char-links.pl ibmdoc-db-lint.pl ibmdoc-merge-docs.pl \
		~/bin/ibmdoc-copy-unhandled-pdfs.pl ~/bin/ibmdoc-create-8char-links.pl ~/bin/ibmdoc-db-lint.pl ~/bin/ibmdoc-merge-docs.pl
	-diff ibmdoc-copy-unhandled-pdfs.pl ~/bin/ibmdoc-copy-unhandled-pdfs.pl > /tmp/ibmdoc-copy-unhandled-pdfs.pl.patch
	-diff ibmdoc-create-8char-links.pl ~/bin/ibmdoc-create-8char-links.pl > /tmp/ibmdoc-create-8char-links.pl.patch
	-diff ibmdoc-db-lint.pl ~/bin/ibmdoc-db-lint.pl > /tmp/ibmdoc-db-lint.pl.patch
	-diff ibmdoc-merge-docs.pl ~/bin/ibmdoc-merge-docs.pl > /tmp/ibmdoc-merge-docs.pl.patch

apypatch: ~/bin/ibmdoc-copy-unhandled-pdfs.pl ~/bin/ibmdoc-create-8char-links.pl ~/bin/ibmdoc-db-lint.pl \
		~/bin/ibmdoc-merge-docs.pl /tmp/ibmdoc-copy-unhandled-pdfs.pl.patch /tmp/ibmdoc-create-8char-links.pl.patch \
		/tmp/ibmdoc-db-lint.pl.patch /tmp/ibmdoc-merge-docs.pl.patch
	patch -R ~/bin/ibmdoc-copy-unhandled-pdfs.pl /tmp/ibmdoc-copy-unhandled-pdfs.pl.patch
	patch -R ~/bin/ibmdoc-create-8char-links.pl /tmp/ibmdoc-create-8char-links.pl.patch
	patch -R ~/bin/ibmdoc-db-lint.pl /tmp/ibmdoc-db-lint.pl.patch
	patch -R ~/bin/ibmdoc-merge-docs.pl /tmp/ibmdoc-merge-docs.pl.patch

clean:
	@rm -f /tmp/ibmdoc-copy-unhandled-pdfs.pl.patch /tmp/ibmdoc-create-8char-links.pl.patch /tmp/ibmdoc-db-lint.pl.patch \
		/tmp/ibmdoc-merge-docs.pl.patch

# vim: tabstop=4 shiftwidth=4 autoindent colorcolumn=133 textwidth=132
