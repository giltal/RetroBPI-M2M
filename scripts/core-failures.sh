#!/bin/bash
L=~/bpi/corelogs
for c in "$@"; do
    echo "=================== $c ==================="
    if [ ! -f "$L/$c.log" ]; then echo "  (no log yet)"; continue; fi
    grep -inE 'error:|Error [0-9]+$|undefined reference|No such file or directory|multiple definition|cannot find -l' "$L/$c.log" | head -12
    echo "  --- last lines ---"
    tail -6 "$L/$c.log"
    echo
done
