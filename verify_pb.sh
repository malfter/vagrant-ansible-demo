#!/usr/bin/env bash
function _getrole() {
  YAML_PATH=${YAMLFILE%/*}
  if echo "$YAML_PATH" | grep -vq "roles/"; then
      exit
  fi
  IFS="/"
  read -ra DIR <<< "$YAML_PATH"
  for (( i=0; i<${#DIR[@]}; i++)); do
      if [[ "${DIR[$i]}" == "roles" ]]; then
          echo "${DIR[$i+1]}"
      fi
  done
}

function _findplaybook() {
  grep "$1" --exclude="*vag*" ansible/*.yml | head -n 1 | cut -d ":" -f 1
}

function _get_pb_hosts() {
  grep "hosts: " "$1" | cut -d ":" -f2 | tr -d " "
}

LAST_COMMITID=$(git log -1 --pretty="%H")
HEAD=$(git rev-parse --short "$(git merge-base origin/master "$LAST_COMMITID")")
mapfile -t FILES < <(git diff --name-only -r "$HEAD" "$LAST_COMMITID")
EXCLUDES=(vagrant/ hosts /group_vars /host_vars README.md .git* .ansible-lint *.cfg)

echo ""
echo "======================= CHANGED FILES ======================"
echo  "${FILES[@]}" | tr " " "\\n" | sed 's/^/  > /'
echo ""
echo "========================= EXCLUDES ========================="


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
echo "====================== MAPPING FILES ======================="
PLAYBOOKS=()
for YAMLFILE in "${FILES[@]}"; do
  ANSIBLE_RESULT_FILTER=""
  # ANSIBLE_RESULT_FILTER="undefined variable|syntax problem"
  ANSIBLEBIN="$(command -v ansible-playbook)"
  export ANSIBLE_ROLES_PATH="./:./roles:ansible/roles"
  [ -n "$YAMLFILE" ] || continue # fix array gaps after filtering exludes
  if [ ! -f "$YAMLFILE" ]; then
    echo -e " \\e[33mYAMLFILE not found: '$YAMLFILE' - skipping...\\e[39m"
    continue
  else
    echo -n "  > '$YAMLFILE'"
  fi
  if [[ ! "$YAMLFILE" == "ansible/"* ]]; then
    echo -e " \\e[33moutside Ansible basedir - skipping...\\e[39m"
    continue
  elif [[ "$YAMLFILE" =~ ansible/[^/]*\.yml  ]]; then
    echo -e " \\e[32mis a playbook\\e[39m"
    PLAYBOOKS+=("$YAMLFILE")
  else
    ROLE=$(_getrole)
    if [ -z "$ROLE" ]; then
      echo -e " \\e[31mno matching role!\\e[39m" >&2
      exit 1
    else
      echo -en " > \\e[32mrole '$ROLE'\\e[39m"
    fi
    PLAYBOOK=$(_findplaybook "$ROLE")
    if [ -z "$PLAYBOOK" ]; then
      echo -e " \\e[31mno matching playbook\\e[39m" >&2
      exit 1
    else
      echo -e " > \\e[32mplaybook '$PLAYBOOK'\\e[39m"
      PLAYBOOKS+=("$PLAYBOOK")
    fi
  fi

done
echo ""
echo "===================== RUNNING CHECKS ======================="
echo ""
PLAYBOOK_UNIQARR=()
while IFS= read -r -d '' x; do
  PLAYBOOK_UNIQARR+=("$x")
done < <(printf "%s\\0" "${PLAYBOOKS[@]}" | sort -uz)
for PB in "${PLAYBOOK_UNIQARR[@]}"; do
  [ -n "$PB" ] || continue # fix array gaps after filtering exludes
  echo -n "  > $PB"
  RESULT="$($ANSIBLEBIN \
            --syntax-check \
            "$(find ansible/ -type d -name "env_*" | sed 's/^/-i/g')" \
            "$PB" 2>&1
            echo $?)"

  RC=$(echo "$RESULT" | tail -1)
  if ! grep -qE "$ANSIBLE_RESULT_FILTER" <<<"$RESULT" && [ "$RC" -ne 0 ]; then
    echo "Result code was $RC but error was filtered by configuration"
    echo -e " \\e[32mPASS\\e[39m"
  elif grep -qE "$ANSIBLE_RESULT_FILTER" <<<"$RESULT" && [ "$RC" -ne 0 ]; then
    echo -e " \\e[31mFAIL\\e[39m"
    echo "===================== ANSIBLE OUTPUT ======================="
    echo ""
    echo "$RESULT"
    echo ""
    echo "============================================================"
    exit 1
  else
    echo -e " \\e[32mPASS\\e[39m"
  fi
done
exit 0
