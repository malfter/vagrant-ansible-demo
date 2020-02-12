#!/bin/bash
set -e

LAST_COMMITID=$(git log -1 --pretty="%H")
HEAD=$(git rev-parse --short $(git merge-base origin/master $LAST_COMMITID))
FILES=$(git diff --name-only -r $HEAD $LAST_COMMITID)
EXCLUDES="vagrant/ .gitlab-ci.yml README.md"

echo ""
echo "=========== CHANGED FILES ======="
echo  "$FILES"
echo ""
echo "=========== EXCLUDES======"
echo  "$EXCLUDES" |tr " " "\n"
echo ""

for i in ${FILES}; do
  checkFile=true
  for ex in ${EXCLUDES}; do
    if $checkfile; then
      if [[ $i == *"$ex/"* || $i == "$ex" || $i == *"/$ex" ]]; then
        FILES=("${FILES[@]/$i}")
        checkFile=false
      fi
    fi
  done
 done

echo "=========== TO CHECK ======="
for file in ${FILES};do
  if ! [ -d $file ] && [ -f $file ]; then
    if [ "${file##*.}" = "j2" ]; then
      echo "> verify_j2.py $file"
      ./verify_j2.py $file
    else
      echo "> no verify for this file $file"
    fi
  fi
done
