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

ls -1 /var/www/default/pages/ibmdocs |grep -E -v \
	-e '^[A-Z0-9]{3,4}-[0-9]{4,5}-[0-9]{2}[A-Za-z]?(-200[0x])?(-de)?\.(pdf|boo)$' \
	-e '^360D[-.][0-9]{2}\.[0-9]\.[0-9]{3}\.(pdf|boo)$' \
	-e '^MPN_5X94-01\.pdf' -e '^SRI-CSL-77-002a\.pdf' \
	-e '^Y27-7128-03\.pdf$'

