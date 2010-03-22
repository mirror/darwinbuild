#!/bin/bash
set -e
set -x

#
# Run tests on darwinup
#

PREFIX=/tmp/testing/darwinup
ORIG=$PREFIX/orig
DEST=$PREFIX/dest
DESTTAR=dest.tar.gz

DARWINUP="darwinup $1 -p $DEST "
DIFF="diff -x .DarwinDepot -x broken -qru"

ROOTS="root root2 root3"

echo "INFO: Cleaning up testing area ..."
rm -rf $PREFIX
mkdir -p $PREFIX

echo "INFO: Untarring the test files ..."
tar zxvf $DESTTAR -C $PREFIX

for R in $ROOTS;
do
	tar zxvf $R.tar.gz -C $PREFIX
done;

for R in root4 root5 root6 root7 symlinks symlink_update;
do
	tar zxvf $R.tar.gz -C $PREFIX
done;

for R in 300dirs.tbz2 300files.tbz2 deep-rollback.cpgz deep-rollback-2.xar;
do
	cp $R $PREFIX/
done;

mkdir -p $ORIG
cp -R $DEST/* $ORIG/

echo "========== TEST: Listing ============="
sudo -u nobody $DARWINUP list
$DARWINUP list

echo "========== TEST: Trying both 32 and 64 bit =========="
for R in $ROOTS;
do
	echo "INFO: Installing $R ...";
	arch -i386 $DARWINUP install $PREFIX/$R
	UUID=$($DARWINUP list | head -3 | tail -1 | awk '{print $1}')
	echo "INFO: Uninstalling $R ...";
	arch -x86_64 $DARWINUP uninstall $UUID
	echo "DIFF: diffing original test files to dest (should be no diffs) ..."
	$DIFF $ORIG $DEST 2>&1
	echo "INFO: Installing $R ...";
	arch -x86_64 $DARWINUP install $PREFIX/$R
	UUID=$($DARWINUP list | head -3 | tail -1 | awk '{print $1}')
	echo "INFO: Uninstalling $R ...";
	arch -i386 $DARWINUP uninstall $UUID
	echo "DIFF: diffing original test files to dest (should be no diffs) ..."
	$DIFF $ORIG $DEST 2>&1
done


echo "========== TEST: Trying roots one at a time =========="
for R in $ROOTS;
do
	echo "INFO: Installing $R ...";
	$DARWINUP install $PREFIX/$R
	UUID=$($DARWINUP list | head -3 | tail -1 | awk '{print $1}')
	echo "INFO: Uninstalling $R ...";
	$DARWINUP uninstall $UUID
	echo "DIFF: diffing original test files to dest (should be no diffs) ..."
	$DIFF $ORIG $DEST 2>&1
done

echo "========== TEST: Multiple argument test ==========";
$DARWINUP install $PREFIX/root{,2,3}
LINES=$($DARWINUP list | wc -l)
if [ $LINES -lt 5 ]; then
	echo "Failed multiple argument test."
	exit 1;
fi
$DARWINUP uninstall all
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1


echo "========== TEST: Trying all roots at once and verifying ==============";
for R in $ROOTS;
do
	echo "INFO: Installing $R ...";
	$DARWINUP install $PREFIX/$R
done

$DARWINUP verify all
$DARWINUP files  all
$DARWINUP dump

echo "========== TEST: uninstall in reverse ==========";
for R in $ROOTS;
do
	UUID=$($DARWINUP list | head -3 | tail -1 | awk '{print $1}')
	echo "INFO: Uninstalling $UUID ...";
	$DARWINUP uninstall $UUID
done	
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1

echo "========== TEST: Trying all roots at once, uninstall in install order by serial =========="
for R in $ROOTS;
do
        echo "INFO: Installing $R ...";
        $DARWINUP install $PREFIX/$R
done
for R in $ROOTS;
do
        UUID=$($DARWINUP list | grep $R$ | awk '{print $1}')
        echo "INFO: Uninstalling $UUID ...";
        $DARWINUP uninstall $UUID
done
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1

echo "========== TEST: Trying all roots at once, uninstall root2, root3, root by UUID =========="
for R in $ROOTS;
do
        echo "INFO: Installing $R ...";
        $DARWINUP install $PREFIX/$R
done
for R in root2 root3 root;
do
        UUID=$($DARWINUP list | grep $R$ | awk '{print $2}')
        echo "INFO: Uninstalling $UUID ...";
        $DARWINUP uninstall $UUID
done
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1

echo "========== TEST: Trying roots in reverse, uninstall in install order =========="
for R in root3 root2 root;
do
        echo "INFO: Installing $R ...";
        $DARWINUP install $PREFIX/$R
done
for R in root3 root2 root;
do
        UUID=$($DARWINUP list | grep $R$ | awk '{print $1}')
        echo "INFO: Uninstalling $UUID ...";
        $DARWINUP uninstall $UUID
done
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1

echo "========== TEST: trying large roots ==========";
echo "INFO: installing 300files";
$DARWINUP install $PREFIX/300files.tbz2
$DARWINUP uninstall 300files.tbz2
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1
echo "INFO: installing 300dir";
$DARWINUP install $PREFIX/300dirs.tbz2
$DARWINUP uninstall 300dirs.tbz2
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1
echo "INFO: installing both 300files and 300dirs";
$DARWINUP install $PREFIX/300dirs.tbz2
$DARWINUP install $PREFIX/300files.tbz2
$DARWINUP uninstall 300dirs.tbz2
$DARWINUP uninstall 300files.tbz2
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1

echo "========== TEST: Try uninstalling with user data in rollback =========="
echo "INFO: Installing root5 ...";
$DARWINUP install $PREFIX/root5
$DARWINUP install $PREFIX/root6
echo "modification" >> $DEST/d/file
$DARWINUP install $PREFIX/root7
$DARWINUP uninstall root6
$DARWINUP uninstall root5
$DARWINUP uninstall root7
stat $DEST/d/file
rm $DEST/d/file
rmdir $DEST/d
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1

echo "========== TEST: Deep rollback while saving user data =========="
$DARWINUP install $PREFIX/deep-rollback.cpgz
echo "modified" >> $DEST/d1/d2/d3/d4/d5/d6/file
$DARWINUP install $PREFIX/deep-rollback.cpgz
$DARWINUP uninstall newest
$DARWINUP uninstall newest
stat $DEST/d1/d2/d3/d4/d5/d6/file
rm $DEST/d1/d2/d3/d4/d5/d6/file
rm -rf $DEST/d1
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1

$DARWINUP install $PREFIX/deep-rollback.cpgz
$DARWINUP install $PREFIX/deep-rollback-2.xar
$DARWINUP uninstall all
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1


echo "========== TEST: Testing broken symlink handling =========="
$DARWINUP install $PREFIX/symlinks
$DARWINUP uninstall symlinks
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1
$DARWINUP install $PREFIX/symlink_update
stat -L $DEST/broken
$DARWINUP uninstall newest
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1

echo "========== TEST: Upgrades ============="
$DARWINUP install $PREFIX/root5
$DARWINUP upgrade $PREFIX/root5
$DARWINUP upgrade $PREFIX/root5
$DARWINUP upgrade $PREFIX/root5
C=$($DARWINUP list | grep root5 | wc -l | xargs)
test "$C" == "1" 
$DARWINUP uninstall oldest
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1

echo "========== TEST: Superseded ============="
$DARWINUP install $PREFIX/root5
$DARWINUP install $PREFIX/root6
$DARWINUP install $PREFIX/root5
$DARWINUP install $PREFIX/root2
$DARWINUP install $PREFIX/root6
$DARWINUP install $PREFIX/root6
$DARWINUP install $PREFIX/root5
$DARWINUP list superseded
$DARWINUP uninstall superseded
C=$($DARWINUP list | grep root | wc -l | xargs)
test "$C" == "2" 
$DARWINUP uninstall oldest
$DARWINUP uninstall oldest
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1


#
# The following are expected failures
#
set +e
echo "========== TEST: Trying a root that will fail due to object change =========="
$DARWINUP install $PREFIX/root4
if [ $? -ne 1 ]; then exit 1; fi
echo "DIFF: diffing original test files to dest (should be no diffs) ..."
$DIFF $ORIG $DEST 2>&1

echo "INFO: Done testing!"

