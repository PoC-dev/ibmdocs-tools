#!/bin/sh

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

set -e

time lynx -source http://webserver/cgi-bin/listdocs \
	> /var/www/default/pages/ibmdocs/index.html

find /var/www/default/pages/ibmdocs \
	-maxdepth 1 -a -type f -a ! -perm 0644 -exec chmod 644 {} \;

find /var/www/default/pages/ibmdocs \
	-maxdepth 1 -a -type f -a ! -group www-data -exec chgrp www-data {} \;
