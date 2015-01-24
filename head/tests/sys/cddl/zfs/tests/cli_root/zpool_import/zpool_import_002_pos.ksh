#!/usr/local/bin/ksh93 -p
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)zpool_import_002_pos.ksh	1.3	07/10/09 SMI"
#
. $STF_SUITE/include/libtest.kshlib
. $STF_SUITE/tests/cli_root/zfs_mount/zfs_mount.kshlib

################################################################################
#
# __stc_assertion_start
#
# ID: zpool_import_002_pos
#
# DESCRIPTION:
# Verify that an exported pool cannot be imported
# more than once.
#
# STRATEGY:
#	1. Populate the default test directory and unmount it.
#	2. Export the default test pool.
#	3. Import it using the various combinations.
#		- Regular import
#		- Alternate Root Specified
#	4. Verify it shows up under 'zpool list'.
#	5. Verify it contains a file.
#	6. Attempt to import it for a second time. Verify this fails.
#
# TESTABILITY: explicit
#
# TEST_AUTOMATION_LEVEL: automated
#
# CODING_STATUS: COMPLETED (2005-07-04)
#
# __stc_assertion_end
#
################################################################################

verify_runnable "global"

set -A pools "$TESTPOOL" "$TESTPOOL1"
set -A devs "" "-d $DEVICE_DIR"
set -A options "" "-R $ALTER_ROOT"
set -A mtpts "$TESTDIR" "$TESTDIR1"


function cleanup
{
	typeset -i i=0
	while (( i < ${#pools[*]} )); do
		poolexists ${pools[i]} && \
			log_must $ZPOOL export ${pools[i]}

		datasetexists "${pools[i]}/$TESTFS" || \
			log_must $ZPOOL import ${devs[i]} ${pools[i]}

		ismounted "${pools[i]}/$TESTFS" || \
			log_must $ZFS mount ${pools[i]}/$TESTFS
	
		[[ -e ${mtpts[i]}/$TESTFILE0 ]] && \
			log_must $RM -rf ${mtpts[i]}/$TESTFILE0

		((i = i + 1))
	done

	cleanup_filesystem $TESTPOOL1 $TESTFS

	destroy_pool $TESTPOOL1

	[[ -d $ALTER_ROOT ]] && \
		log_must $RM -rf $ALTER_ROOT
}

log_onexit cleanup

log_assert "Verify that an exported pool cannot be imported more than once."

setup_filesystem "$DEVICE_FILES" $TESTPOOL1 $TESTFS $TESTDIR1

checksum1=$($SUM $MYTESTFILE | $AWK '{print $1}')

typeset -i i=0
typeset -i j=0
typeset basedir

while (( i < ${#pools[*]} )); do
	log_must $CP $MYTESTFILE ${mtpts[i]}/$TESTFILE0

	log_must $ZFS umount ${mtpts[i]}

	j=0
	while (( j <  ${#options[*]} )); do
		typeset pool=${pools[i]}
		k=0
		while (( k < 2 )); do
			typeset target=$pool
			log_must $ZPOOL export $pool

			if (( k == 1 )); then
				typeset vdevdir=""
				if [[ "$pool" = "$TESTPOOL1" ]]; then
					vdevdir="$DEVICE_DIR"
				fi
				target=$(get_config $pool pool_guid $vdevdir)
				log_must test -n "$target"
				log_note "Importing '$pool' by guid '$target'."
			fi

			log_must $ZPOOL import ${devs[i]} ${options[j]} $target
			log_must poolexists $pool
			log_must ismounted $pool/$TESTFS

			basedir=${mtpts[i]}
			[[ -n ${options[j]} ]] && \
				basedir=$ALTER_ROOT/${mtpts[i]}

			[[ ! -e $basedir/$TESTFILE0 ]] && log_fail \
				"$basedir/$TESTFILE0 missing after import."

			checksum2=$($SUM $basedir/$TESTFILE0 | $AWK '{print $1}')
			[[ "$checksum1" != "$checksum2" ]] && log_fail \
				"Checksums differ ($checksum1 != $checksum2)"

			log_mustnot $ZPOOL import ${devs[i]} $target

			(( k = k + 1 ))
		done

		((j = j + 1))
	done

	((i = i + 1))

done

log_pass "Able to import exported pools and import only once."
