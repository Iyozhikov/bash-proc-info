#!/bin/bash
# Script shows pids of given process name
# provides as-is
# Author: Igor Yozhikov <iyozhikov@mirantis.com>
debug=${debug:-false}
parent_id=0
procname_to_find=$1
declare -a proc_children

function show_usage()
{
  local script_name=$(basename "$0")
  echo "Usage:"
  echo " $script_name process_name [subcommand]"
  echo " subcommands:"
  echo "  if not set - displays all process ids, parent pid goes first"
  echo "  get-parent - displays only parent process id"
  echo "  get-children - displays only children process ids"
}

function log()
{
  if [[ "$debug" == true ]]; then
    local msg="$*"
    echo "$(date +"%m-%d-%Y %H:%M") -> $msg"
  fi
}

function get_children()
{
  local parent_id=$1
# Searching children in the main thread
  local childrenfiles="/proc/${parent_id}/children /proc/${parent_id}/task/${parent_id}/children"
  for childrenfile in $childrenfiles;
  do
    if [ -f "$childrenfile" ]; then
      while read child;
      do
        # if [ "$child" -ne "$parent_id" ]; then
          proc_children+=("$child")
        # fi
      done <<< "$(cat "$childrenfile")"
    fi
  done
}

function get_parent()
{
  local pid=$1
  local is_we_are_parent=${2:-false}
  local parent_id=$(awk '{print $4}' /proc/"$pid/stat")
  local parent_name=$(cat /proc/"$parent_id"/comm)
# Checking for parent is not init!
  if [[ "$parent_name" == "init" ]]; then
    echo 0
  else
    if [[ $is_we_are_parent == true ]]; then
      echo 1
    else
      echo $parent_id
    fi
  fi
}

function get_process_data()
{
  local proc=$1
  local proc_id=$(pidof -x "$proc" | awk '{print $1}')
  if [ -z "$proc_id" ]; then
    log "Process id for $proc is not found!"
    exit 1
  fi
  if [ "$(get_parent "$proc_id" true)" -eq 0 ]; then
    parent_id=$proc_id
  else
    parent_id="$(get_parent "$proc_id")"
  fi
  get_children "$parent_id"
}
if [ $# -eq 0 ]; then
  show_usage
  exit 1
fi
get_process_data "$procname_to_find"
case $2 in
  get-parent)
    log "Showing only parent pid for $procname_to_find:"
    echo "$parent_id"
    ;;
  get-children)
    log "Showing only children pids for parent $procname_to_find($parent_id):"
    echo "${proc_children[*]}"
    ;;
  *)
    log "Showing all pids for $procname_to_find, parent pid goes first:"
    echo "$parent_id ${proc_children[*]}"
    ;;
esac
