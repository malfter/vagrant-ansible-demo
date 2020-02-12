#!/bin/bash

function _getrole() {
  YAML_PATH=${YAMLFILE%/*}
  if echo $YAML_PATH | grep -vq "roles/"; then
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
HEAD=$(git rev-parse --short $(git merge-base origin/master $LAST_COMMITID))
FILES=$(git diff --name-only -r $HEAD $LAST_COMMITID)
EXCLUDES="vagrant/ hosts /group_vars /host_vars README.md .git* .ansible-lint *.cfg"

echo ""
echo "======================= CHANGED FILES ======================"
echo  "$FILES"
echo ""
echo "========================= EXCLUDES ========================="
echo ""

for i in ${FILES}; do
  checkFile=true
  for ex in ${EXCLUDES}; do
    if $checkfile; then
      if [[ $i == *"$ex/"* || $i == "$ex" || $i == *"/$ex" ]]; then
        echo "Excluding '$i'"
        FILES=("${FILES[@]/$i}")
        checkFile=false
      fi
    fi
  done
 done
echo ""
echo "====================== MAPPING FILES ======================="
echo ""
PLAYBOOKS=()
for YAMLFILE in ${FILES[@]}; do
  ANSIBLE_RESULT_FILTER=""
  # ANSIBLE_RESULT_FILTER="undefined variable|syntax problem"
  ANSIBLEBIN="$(command -v ansible-playbook)"
  export ANSIBLE_ROLES_PATH="./:./roles:ansible/roles"

  if [ ! -f "$YAMLFILE" ]; then
    echo "YAMLFILE not found: '$YAMLFILE' - skipping..."
    continue
  else
    echo -n "Mapping '$YAMLFILE'"
  fi
  if [[ ! "$YAMLFILE" == "ansible/"* ]]; then
    echo "> outside Ansible basedir - skipping..."
    continue
  elif [[ "$YAMLFILE" =~ ansible/[^/]*\.yml  ]]; then
    echo " > is a playbook"
    PLAYBOOKS+=($YAMLFILE)
  else
    ROLE=$(_getrole)
    if [ -z "$ROLE" ]; then
      echo "> no matching role!" >&2
      exit 1
    else
      echo -n " > role '$ROLE'"
    fi
    PLAYBOOK=$(_findplaybook "$ROLE")
    if [ -z "$PLAYBOOK" ]; then
      echo "> no matching playbook" >&2
      exit 1
    else
      echo " > playbook '$PLAYBOOK'"
      PLAYBOOKS+=($PLAYBOOK)
    fi
  fi

done
echo ""
echo "===================== RUNNING CHECKS ======================="
echo ""
PLAYBOOK_UNIQARR=()
while IFS= read -r -d '' x; do
  PLAYBOOK_UNIQARR+=("$x")
done < <(printf "%s\0" "${PLAYBOOKS[@]}" | sort -uz)
echo "${#PLAYBOOK_UNIQARR[@]} playbook(s) to be checked:"
for PB in ${PLAYBOOK_UNIQARR[@]}; do
echo $PB
  echo -n "$PB"
  RESULT="$($ANSIBLEBIN \
            --syntax-check \
            $(find ansible/ -type d -name "env_*" | sed 's/^/-i/g') \
            "$PB" 2>&1
            echo $?)"

  RC=$(echo "$RESULT" | tail -1)
  if ! grep -qE "$ANSIBLE_RESULT_FILTER" <<<"$RESULT" && [ "$RC" -ne 0 ]; then
    echo "Result code was $RC but error was filtered by configuration"
    echo " > PASS"
  elif grep -qE "$ANSIBLE_RESULT_FILTER" <<<"$RESULT" && [ "$RC" -ne 0 ]; then
    echo " > FAIL"
    echo "===================== ANSIBLE OUTPUT ======================="
    echo ""
    echo "$RESULT"
    echo ""
    echo "============================================================"
    exit 1
  else
    echo " > PASS"
  fi
done
exit 0
