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
    if  [[ "$(head -1 $file)" =~ .*\$ANSIBLE_VAULT.* ]]; then
      echo "> file \"$file\" is encrypted, skipping..... "
    elif ! [[ "$(head -1 $file)" =~ .*\$ANSIBLE_VAULT.* ]] && ! [[ $file == *"."* ]]; then
      if [[ $file == *"/group_vars/"* ]] || [[ $file == *"/hosts_vars/"* ]]; then
        echo "> ansible-lint $file"
        ansible-lint "$file"
      else
        echo "> no verify for this file $file"
      fi
    elif [ "${file##*.}" = "yml" ]; then
      echo "> ansible-lint $file"
      ansible-lint "$file"
    else
      echo "> no verify for this file $file"
    fi
  fi
done
