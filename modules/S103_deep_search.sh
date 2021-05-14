#!/bin/bash

# emba - EMBEDDED LINUX ANALYZER
#
# Copyright 2020-2021 Siemens AG
# Copyright 2020-2021 Siemens Energy AG
#
# emba comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
# welcome to redistribute it under the terms of the GNU General Public License.
# See LICENSE file for usage of this software.
#
# emba is licensed under GPLv3
#
# Author(s): Michael Messner, Pascal Eckmann

# Description:  Searches for files with a specified string pattern inside.
export THREAD_PRIO=1

S103_deep_search()
{
  module_log_init "${FUNCNAME[0]}"
  module_title "Deep analysis of files for patterns"

  local PATTERNS
  PATTERNS="$(config_list "$CONFIG_DIR""/deep_search.cfg" "")"

  print_output "[*] Patterns: ""$( echo -e "$PATTERNS" | sed ':a;N;$!ba;s/\n/ /g' )""\\n"
  
  readarray -t PATTERN_LIST < <(printf '%s' "$PATTERNS")

  if ! [[ -d "$LOG_DIR""/deep_search/" ]] ; then
    mkdir "$LOG_DIR""/deep_search/" 2> /dev/null
  fi

  OCC_LIST=()

  deep_pattern_search
  deep_pattern_reporter

  module_end_log "${FUNCNAME[0]}" "${#OCC_LIST[@]}"
}

deep_pattern_search() {
  local WAIT_PIDS_S103=()
  local COUNT=0
  GREP_PATTERN_COMMAND=()
  for PATTERN in "${PATTERN_LIST[@]}" ; do
    GREP_PATTERN_COMMAND=( "${GREP_PATTERN_COMMAND[@]}" "-e" ".{0,15}""$PATTERN"".{0,15}" )
  done
  echo
  for DEEP_S_FILE in "${FILE_ARR[@]}"; do
    if [[ $THREADED -eq 1 ]]; then
      deep_pattern_searcher &
      WAIT_PIDS_S103+=( "$!" )
    else
      deep_pattern_searcher
    fi
  done

  if [[ $THREADED -eq 1 ]]; then
    wait_for_pid "${WAIT_PIDS_S103[@]}"
  fi
}

deep_pattern_searcher() {
  if [[ -e "$DEEP_S_FILE" ]] ; then
    local S_OUTPUT
    readarray -t S_OUTPUT < <(grep -E -n -a -h -o -i "${GREP_PATTERN_COMMAND[@]}" -D skip "$DEEP_S_FILE" | tr -d '\0')
    if [[ ${#S_OUTPUT[@]} -gt 0 ]] ; then
      echo "[+] ""$DEEP_S_FILE" >> "$LOG_DIR""/deep_search/deep_search_""$(basename "$DEEP_S_FILE")"".txt"
      for DEEP_S_LINE in "${S_OUTPUT[@]}" ; do
        DEEP_S_LINE="$( echo "$DEEP_S_LINE" | tr "\000-\037\177-\377" "." )"
        echo "$DEEP_S_LINE" >> "$LOG_DIR""/deep_search/deep_search_""$(basename "$DEEP_S_FILE")"".txt"
      done
      local D_S_FINDINGS=""
      for PATTERN in "${PATTERN_LIST[@]}" ; do
        F_COUNT=$(grep -i "$PATTERN" "$LOG_DIR""/deep_search/deep_search_""$(basename "$DEEP_S_FILE")"".txt" | wc -l )
        if [[ $F_COUNT -gt 0 ]] ; then
          D_S_FINDINGS="$D_S_FINDINGS""    ""$F_COUNT""\t:\t""$PATTERN""\n"
        fi
      done
      #COUNT=((COUNT+${#S_OUTPUT[@]}))
      print_output "[+] ""$DEEP_S_FILE""$NC""\\n""$D_S_FINDINGS"  
    fi
  fi
}

deep_pattern_reporter() {
  for PATTERN in "${PATTERN_LIST[@]}" ; do
    P_COUNT=$(grep -i "$PATTERN" "$LOG_FILE" | cut -f 1 | sed 's/\ //g' | awk '{ SUM += $1} END { print SUM }' )
    OCC_LIST=( "${OCC_LIST[@]}" "$P_COUNT"": ""$PATTERN" )
  done

  if [[ "${#PATTERN_LIST[@]}" -gt 0 ]] ; then
    print_output "[*] Occurences of pattern:"
    SORTED_OCC_LIST=("$(printf '%s\n' "${OCC_LIST[@]}" | sort -r --version-sort)")
    for OCC in "${SORTED_OCC_LIST[@]}"; do
      print_output "$( indent "$(orange "$OCC" )")""\n"
    done
  fi
}
