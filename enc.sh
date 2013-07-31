#!/bin/bash

# enc - EncFS CLI manager.
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

_VER="0.1-4"

# Configuration
ENCFS_BIN="/usr/bin/encfs"
ENCFSCTL_BIN="/usr/bin/encfsctl"
ZIP_BIN="/usr/bin/zip"

CONFIG="$HOME/.enc.conf"
STAT_FILE="/tmp/enc-$USER"
ENC_DIR="$HOME/.enc"
MNT_DIR="$HOME/enc"

# Create status file
function create_stat_file ()
{
	touch "$STAT_FILE"
	
	if [ ! $? -eq 0 ]; then
		return 1
	fi
	
	chmod 600 "$STAT_FILE"
	
	return 0
}

# Write mounted stash into status file
function push_into_stat_file ()
{
	als=$1
	mnt=$2
	
	echo "$als $mnt" >> "$STAT_FILE"
}

# Remove umounted stash from status file
function pull_from_stat_file ()
{
	als=$1
	
	sed -i '/^'$als' /d' "$STAT_FILE"
}

# Delete status file
function delete_stat_file ()
{
	rm -f "$STAT_FILE"
}

# Calculate stash size and print it in human readable format
function get_stash_size ()
{
	als=$1
	total_b=$(du -bc "$ENC_DIR/.$als" | tail -1 | awk '{ print $1 }')

	if [ $total_b -lt 1024 ]; then
		size=$total_b
		unit="B"
	fi

	# Convert to kB
	if [ $total_b -gt 1024 ]; then
		size=$(echo "scale=2; $total_b / 1024" | bc -l)
		unit="kB"
	fi
		
	# Convert to MB
	if [ $total_b -gt 1048576 ]; then
		size=$(echo "scale=2; $total_b / 1024 / 1024" | bc -l)
		unit="MB"
	fi
	
	# Convert to GB
	if [ $total_b -gt 1073741824 ]; then
		size=$(echo "scale=2; $total_b / 1024 / 1024 / 1024" | bc -l)
		unit="GB"
	fi
	
	echo "$size $unit"
}

# Check whether stash is set
function probe ()
{
	als=$1

	if [ ! -d "$ENC_DIR/.$als" ]; then
		return 1
	fi
	
	return 0
}

# Check if stash is mounted (checks existence of the mount point)
# Return: 0 if mounted or number greater than 0 otherwise
function is_mounted ()
{
	als=$1
	
	if [ ! -f "$STAT_FILE" ]; then
		return 1
	fi
	
	grep -e "^$als " "$STAT_FILE" 2>&1 > /dev/null
	
	return $?
}

# Mount stash
function mount_stash ()
{
	als=$1
	mnt=$2
	
	create_stat_file
	
	if [ ! $? -eq 0 ]; then
		return 1
	fi
	
	$ENCFS_BIN "$ENC_DIR/.$als" "$mnt"
	
	if [ ! $? -eq 0 ]; then
		return 1
	fi
	
	push_into_stat_file "$als" "$mnt"
	
	return 0
}

# Umount stash
function umount_stash ()
{
	als=$1
	mnt=$(get_mount_point "$als")
		
	fusermount -u "$mnt" 2> /dev/null
	
	if [ ! $? -eq 0 ];then
		return 1
	fi
	
	# Remove mount point if the directory is in $MNT_DIR
	# Fixme: i should use some regular expression with substitution in order to get
	# rid of the last slash '/'.
	if [ "$(dirname "$mnt")" == "$(dirname "$MNT_DIR")/$(basename "$MNT_DIR")" ]; then
		rmdir "$mnt" 2>&1 > /dev/null
	fi
	
	pull_from_stat_file "$als"
	
	if [ ! -s "$STAT_FILE" ]; then
		delete_stat_file
	fi
	
	return 0
}

# Get mount point of given stash
function get_mount_point ()
{
	als=$1
	
	grep -e "^$als " "$STAT_FILE" 2> /dev/null | awk '{ print $2 }'
}

p=$(basename $0)

cmd=$1

# Load configuration file
if [ -f "$CONFIG" ]; then
	source "$CONFIG"
fi

if [ ! -d "$ENC_DIR" ]; then mkdir -p "$ENC_DIR"; fi
if [ ! -w "$ENC_DIR" ]; then echo "$p: directory '$ENC_DIR' is not writable."; exit 1; fi
if [ ! -d "$MNT_DIR" ]; then mkdir "$MNT_DIR"; fi
if [ ! -w "$MNT_DIR" ]; then echo "$p: directory '$MNT_DIR' is not writable."; exit 1; fi

# Check if required binaries are available
if [ ! -x "$ENCFS_BIN" ]; then echo "$p: encfs '$ENCFS_BIN' is not available."; exit 1; fi
if [ ! -x "$ENCFSCTL_BIN" ]; then echo "$p: encfsctl '$ENCFSCTL_BIN' is not available."; exit 1; fi
if [ ! -x "$ZIP_BIN" ]; then echo "$p: zip '$ZIP_BIN' is not available."; exit 1; fi

if [ $# -eq 0 ]; then
	echo -e "$p v$_VER\n\nUsage:\n\t$p <stash> [mount_point]\n\t$p add <stash>\n\t$p psw <stash>\n\t$p del <stash>\n\t$p zip <stash> <output>\n\nStashes:"
	
	for dir in $(ls -1A "$ENC_DIR");
	do
		# Skip files that are not a directory
		if [ ! -d "$ENC_DIR/$dir" ]; then
			continue
		fi
		
		stash="${dir/./}"
		
		is_mounted "$stash"
		
		if [ $? -eq 1 ]; then
			echo -e "\t$stash ($(get_stash_size "$stash"))"
		else
			echo -e "\t*$stash ($(get_stash_size "$stash")) => $(get_mount_point "$stash")"
		fi
	done
	
	exit 0;
fi

case "$cmd" in

# Add new stash
	add )
		stash=$2
		
		if [ -z "$stash" ]; then
			echo "$p: stash is an empty string."
			exit 1
		fi
		
		if [ "$stash" == "add" ] || [ "$stash" == "del" ] || [ "$stash" == "psw" ] || [ "$stash" == "zip" ]; then
			echo "$p: invalid stash name."
			exit 1
		fi
		
		probe "$stash"
		
		if [ $? -eq 0 ]; then
			echo "$p: stash '$stash' is already in use."
			exit 1
		fi
		
		mkdir "$ENC_DIR/.$stash"
		
		if [ ! $? -eq 0 ]; then
			echo "$p: could not create directory '$ENC_DIR/.$stash'."
			exit 1
		fi
		
		echo "$p: new stash '$stash' added."
		;;
# Delete stash
	del )
		stash=$2
		
		if [ -z "$stash" ]; then
			echo "$p: stash is an empty string."
			exit 1
		fi
		
		probe "$stash"
		
		if [ ! $? -eq 0 ]; then
			echo "$p: unknown stash '$stash'."
			exit 1
		fi

		is_mounted "$stash"
		
		if [ $? -eq 0 ]; then
			echo "$p: cannot delete stash '$stash' - is mounted."
			exit 1
		fi

		rm -r "$ENC_DIR/.$stash"
		
		if [ ! $? -eq 0 ]; then
			echo "$p: could not delete directory '$ENC_DIR/.$stash'."
			exit 1
		fi
		
		echo "$p: stash '$stash' deleted."
		;;
# Change password
	psw )
		stash=$2
		
		if [ -z "$stash" ]; then
			echo "$p: stash is an empty string."
			exit 1
		fi
		
		probe "$stash"
		
		if [ ! $? -eq 0 ]; then
			echo "$p: unknown stash '$stash'."
			exit 1
		fi
		
		$ENCFSCTL_BIN passwd "$ENC_DIR/.$stash"
	;;
# Zip stash
	zip )
		stash=$2
		output=$3
		
		if [ -z "$stash" ]; then
			echo "$p: stash is an empty string."
			exit 1
		fi
		
		probe "$stash"
		
		if [ ! $? -eq 0 ]; then
			echo "$p: unknown stash '$stash'."
			exit 1
		fi
		
		if [ -z "$output" ]; then
			echo "$p: output file is an empty string."
			exit 1
		fi
		
		if [ -f "$output" ]; then
			echo "$p: output file '$output' already exists."
			exit 1
		fi
		
		mkdir "/tmp/$stash" 2>&1 > /dev/null
		
		if [ ! $? -eq 0 ]; then
			echo "$p: could not create temporary directory '/tmp/$stash'"
			exit 1
		fi
		
		find "$ENC_DIR/.$stash" -mindepth 1 -exec cp -rf "{}" "/tmp/$stash" \;
		
		cd "/tmp"
		
		$ZIP_BIN -r "$output" "$stash" 2>&1 > /dev/null
		zip_status=$?
		
		# Remove temporary directory
		rm -rf "/tmp/$stash"
		
		if [ ! $zip_status -eq 0 ]; then
			echo "$p: could not create zip archive '$output'."
			exit 1
		fi
		
		echo "$p: archive '$output' created."
	;;
# Mount stash
	* )
		stash=$1
		mount_point=$2
		
		probe "$stash"
		
		if [ ! $? -eq 0 ]; then
			echo "$p: unknown stash '$stash'."
			exit 1
		fi
		
		if [ -z "$mount_point" ]; then
			mount_point="$MNT_DIR/$stash"
			if [ ! -d "$mount_point" ]; then
				mkdir "$mount_point"
			fi
		fi
		
		if [ ! -d "$mount_point" ]; then
			echo "$p: directory '$mount_point' does not exists."
			exit 1
		fi
		
		if [ ! -w "$mount_point" ]; then
			echo "$p: directory '$mount_point' is not writable."
			exit 1
		fi
				
		# Enforce full path
		mount_point="$(readlink -f "$mount_point")"
		
		is_mounted "$stash"
		
		if [ $? -eq 1 ]; then
			# Check whether mounted directory contains any files
			if [ $(ls -1 "$mount_point" 2> /dev/null | wc -l) -gt 0 ]; then
				echo "$p: directory '$mount_point' is not empty."
				exit 1
			fi
			
			mount_stash "$stash" "$mount_point"
			
			if [ ! $? -eq 0 ]; then
				echo "$p: could not mount stash '$stash'."
				exit 1
			fi
			
			echo "$p: stash '$stash' mounted."
		else
			umount_stash "$stash"
			
			if [ ! $? -eq 0 ]; then
				echo "$p: could not umount stash '$stash' - is busy."
				exit 1
			fi
			
			echo "$p: stash '$stash' umounted."
		fi
		;;
esac

exit 0
