#!/bin/bash
# gpx2tcx.sh by Paul Colby (http://colby.id.au), no rights reserved ;)
# $Id: gpx2tcx.sh 263 2012-02-11 03:16:18Z paul $
 
function showUsage {
  SCRIPT_NAME=`basename $0 .sh`
  echo -e "\nUsage: $SCRIPT_NAME [options] [base_filename[.gpx|hrm]] ... [base_filename[.gpx|hrm]]\n"
  echo 'Allowed options:'
  echo '  -a meters  user meters as the starting altitude if no HRM altitude data present'
  echo '  -f         overwrite destination file if any exists'
  echo '  -h         show this help text and exit'
  echo '  -s sport   set TCX activity type to sport; should be one of "Biking", "Running", or "Other";'
  echo '             if not set, will use "Biking" if cadence data is present, otherwise "Running"'
  echo "  -v         report this script's version and exit"
  echo '  -z offset  replace UTZ "Z" timezone suffixes with offset (eg "+11:00")'
  echo
}
 
function showVersion {
  # Note, Subversion will automatically update the following line.
  SCRIPT_VERSION=( 1 0 0 `echo '$Revision: 263 $' | sed -e 's/.*: *\([0-9]\+\).*$/\1/'` )
  echo "${SCRIPT_VERSION[0]}.${SCRIPT_VERSION[1]}.${SCRIPT_VERSION[2]}.${SCRIPT_VERSION[3]}"
}
 
function parseCommandLine {
  unset ALTITUDE
  unset FORCE
  unset SPORT
  unset TIMEZONE
  if [ -r ~/".`basename $0 .sh`" ]; then . ~/".`basename $0 .sh`"; fi
  local -a ERRORS
  while getopts ':a:fhs:vz:' OPTION; do
    case $OPTION in
      a) ALTITUDE="$OPTARG"   ;;
      f) FORCE=Y              ;;
      h) showUsage   ; exit 0 ;;
      s) SPORT="$OPTARG"      ;;
      v) showVersion ; exit 0 ;;
      z) TIMEZONE="$OPTARG"   ;;
      :) ERRORS[${#ERRORS[@]}]="Option -$OPTARG requires an argument." ;;
     \?) ERRORS[${#ERRORS[@]}]="Option -$OPTARG not known."            ;;
      *) ERRORS[${#ERRORS[@]}]="Option -$OPTION not implemented yet."  ;;
    esac
  done
  shift $(( $OPTIND - 1))
 
  if [ ${#ERRORS[@]} -gt 0 ]; then
    for ERROR in "${ERRORS[@]}"; do
      echo "$ERROR" >&2
    done
    showUsage ; exit 1
  fi
 
  # All positional arguments are [base] filenames.
  unset $FILENAMES
  for POSITIONAL_ARGUMENT; do
    FILENAMES[${#FILENAMES[@]}]=$POSITIONAL_ARGUMENT
  done
 
  # If no filenames where specified, look for GPX/HRM files in the current directory.
  if [ ${#FILENAMES[@]} -eq 0 ]; then
    local PREVIOUS_IFS="$IFS"
    IFS=$'\n'
    FILENAMES=( `find . -name '*.gpx' | sed -e 's/\.[^.]*$//' | sort | uniq` )
    if [ -z "$FORCE" ]; then
      # Not forcing output, so ignore any input files that have already have corresponding TCX files.
      FILENAMES=( $( for NAME in "${FILENAMES[@]}"; do if [ ! -e "$NAME.tcx" ]; then echo "$NAME"; fi; done ) )
    fi
    IFS="$PREVIOUS_IFS"
 
    # See if we actually found any files to process.
    if [ ${#FILENAMES[@]} -eq 0 ]; then
      echo "Found no files to process."
      exit 0
    fi
  else
    # Remove any .gpx/.hrm suffixes from the user-supplied list, and uniquify.
    local PREVIOUS_IFS="$IFS"
    IFS=$'\n'
    FILENAMES=( $( for NAME in "${FILENAMES[@]}"; do echo $NAME; done | sed -e 's/\.\(hrm\|gpx\)$//' | sort -u ) )
    IFS="$PREVIOUS_IFS"
  fi
}
 
function merge {
  if [ -z "$FORCE" ] && [ -e "$1.tcx" ]; then
    echo "Skipping \"$1\" - output file (\"$1.tcx\") already exists." >&2
    return 0
  fi
 
  echo "Processing $1"
  awk -f "`dirname $0`/`basename $0 sh`awk" -v ALTITUDE="$ALTITUDE" -v HRMFILE="$1.hrm" -v SPORT="$SPORT" "$1.gpx" > "$1.tcx"
 
  if [ -n "$TIMEZONE" ]; then
    sed -i -re "s/([>\"][0-9]{4}(-[0-9]{2}){2}T([0-9]{2}:){2}[0-9]{2})Z([<\"])/\1$TIMEZONE\4/g" "$1.tcx"
  fi
}
 
function mergeAll {
  for FILENAME in "${FILENAMES[@]}"; do
    merge "$FILENAME"
  done
}
 
parseCommandLine "$@"
mergeAll
