#!/usr/bin/env bash
set -e

LAST_COMMITID=$(git log -1 --pretty="%H")
HEAD=$(git rev-parse --short "$(git merge-base origin/master "$LAST_COMMITID")")
mapfile -t FILES < <(git diff --name-only -r "$HEAD" "$LAST_COMMITID")
EXCLUDES=(vagrant/ .yaml .sh .yml)

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
    if [ "${file##*.}" = "j2" ]; then
      echo -n "  > $file"
      if ./verify_j2.py "$file"; then
        echo -e " \\e[32mPASS\\e[39m"
      else
        echo -e " \\e[31mFAIL\\e[39m"
        exit 1
      fi
    else
      echo "> no verify for this file $file"
    fi
  fi
done
exit 0
