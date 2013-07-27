#!/bin/bash

# enc - enc installer script.
# Copyright (C) 2013 Erl Cash <erlcash@codeward.org>
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.

ENC_BIN="enc.sh"
EXAMPLE_CONF="enc.conf.example"

if [ ! $UID -eq 0 ]; then
	echo "$0: you must be root to run this script."
	exit 1
fi

if [ ! -f "$ENC_BIN" ]; then
	echo "$0: enc '$ENC_BIN' not found."
	exit 1
fi

if [ ! -f "$EXAMPLE_CONF" ]; then
	echo "$0: enc configuration file '$EXAMPLE_CONF' not found."
	exit 1
fi

echo -n "$ENC_BIN => /usr/bin/$(basename "$ENC_BIN" ".sh") "

install "$ENC_BIN" "/usr/bin/$(basename "$ENC_BIN" ".sh")" 2>&1 > /dev/null

if [ ! $? -eq 0 ]; then
	echo "[FAILED]"
	exit 1
else
	echo "[OK]"
fi

echo "Do you wish to create a copy of configuration file in directory '$HOME/.$(basename "$EXAMPLE_CONF" ".example")'?"
read -p "Choose (Y/n) " option

if [ "$option" == "Y" ] || [ -z "$option" ] || [ "$option" == "y" ]; then
	echo -n "$EXAMPLE_CONF => $HOME/.$(basename "$EXAMPLE_CONF" ".example") "
	install -o "$SUDO_USER" -m 600 "$EXAMPLE_CONF" "$HOME/.$(basename "$EXAMPLE_CONF" ".example")" 2>&1 > /dev/null
	
	if [ ! $? -eq 0 ]; then
		echo "[FAILED]"
		exit 1
	else
		echo "[OK]"
	fi
fi

exit 0
