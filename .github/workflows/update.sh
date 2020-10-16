#!/bin/bash
set -e
shopt -s extglob

echo "Fetch manifest..."
wget --no-verbose -O manifest.txt https://decentespresso.com/download/sync/de1beta/manifest.txt

echo "Checking if there are differences..."
git diff --exit-code manifest.txt && HAS_CHANGES=$? || HAS_CHANGES=$?

if [ $HAS_CHANGES -eq 0 ]
then
  echo "No changes!"
else
  echo "Updates available!"

  echo "Removing all source files..."
  rm -rv !(README.md|manifest.txt|.git*|.|..)

  echo "Creating list of files to download..."
  grep -Eo '"(.*)"' manifest.txt | cut -d '"' -f2 | sed 's/^/https:\/\/decentespresso.com\/download\/sync\/de1beta\//' > files.txt

  echo "Fetching all the files from manifest.txt..."
  wget --no-verbose --force-directories --no-host-directories --cut-dirs=3 --input-file=files.txt

  echo "Fetching new timestamp.txt..."
  wget --no-verbose https://decentespresso.com/download/sync/de1beta/timestamp.txt

  echo "Removing temporary filelist..."
  rm files.txt

  TS=$(cat timestamp.txt | tr -d '[:space:]')
  MESSAGE=$(printf '%(%F %T %Z)T\n' $TS)

  echo "Pushing v$TS to git..."
  git config --local user.email "mirror@decentespresso.com"
  git config --local user.name "Decent Espresso"
  git add --all
  git commit --all --message="$MESSAGE"
  git tag --annotate v$TS --message="$MESSAGE"
  git status
  git push --follow-tags
fi
