#!/usr/bin/env bash
set -e

LAST_COMMITID=$(git log -1 --pretty="%H")
HEAD=$(git rev-parse --short "$(git merge-base origin/master "$LAST_COMMITID")")
mapfile -t FILES < <(git diff --name-only -r "$HEAD" "$LAST_COMMITID")
EXCLUDES=(vagrant/ .sh)
echo ""
echo "=========== CHANGED FILES ======="
echo  "${FILES[@]}" | tr " " "\\n" | sed 's/^/  > /'
echo ""
echo "=========== EXCLUDES======"

for i in "${FILES[@]}"; do
  for ex in "${EXCLUDES[@]}"; do
    if [[ "$i" == *"$ex/"* || "$i" == "$ex" || "$i" == *"/$ex" || "$i" == *"$ex"  ]]; then
      echo -e "  > \\e[33mexcluding $i\\e[39m"
      FILES=( "${FILES[@]/$i}" )
      break
    fi
  done
done

echo ""
echo "=========== TO CHECK ======="
for file in "${FILES[@]}";do
  if ! [ -d "$file" ] && [ -f "$file" ]; then
    if  [[ "$(head -1 "$file")" =~ .*\$ANSIBLE_VAULT.* ]]; then
      echo "> file \"$file\" is encrypted, skipping..... "
    elif ! [[ "$(head -1 "$file")" =~ .*\$ANSIBLE_VAULT.* ]] && ! [[ $file == *"."* ]]; then
      if [[ $file == *"/group_vars/"* ]] || [[ $file == *"/hosts_vars/"* ]]; then
        echo -n "  > $file"
        if RESULT=$(ansible-lint "$file"); then
          echo -e "\\e[32mPASS\\e[39m"
        else
          echo -en "\\e[31mFAIL "
          echo -e "$RESULT\\e[39m" | cut -d ":" -f 2-3
          exit 1
        fi
      else
        echo "> no verify for this file $file"
      fi
    elif [ "${file##*.}" = "yml" ]; then
      echo -n "  > $file "
        if RESULT=$(ansible-lint "$file"); then
          echo -e "\\e[32mPASS\\e[39m"
        else
          echo -en "\\e[31mFAIL "
          echo -e "$RESULT\\e[39m" | cut -d ":" -f 2-3
          exit 1
        fi
    else
      echo "> no verify for this file $file"
    fi
  fi
done
