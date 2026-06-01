#!/bin/bash

# Syncs participants.tsv with the sub-* directories present in the BIDS dataset.
# Adds rows for subjects that are on disk but missing from the TSV.
# Does NOT remove rows for subjects that have been deleted — use --prune for that.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIDS_DIR="$(dirname "$SCRIPT_DIR")"
TSV="$BIDS_DIR/participants.tsv"

usage() {
    cat <<EOF
Usage:
  bash $0 [--prune] [--dry-run]

Optional:
  --prune     Also remove rows for subjects no longer present on disk
  --dry-run   Show what would change without modifying participants.tsv

Examples:
  bash $0
  bash $0 --dry-run
  bash $0 --prune
EOF
}

PRUNE=false
DRYRUN=false

for arg in "$@"; do
    case "$arg" in
        --prune)   PRUNE=true ;;
        --dry-run) DRYRUN=true ;;
        --help)    usage; exit 0 ;;
        *) echo "ERROR: unknown option: $arg"; usage; exit 1 ;;
    esac
done

if [[ ! -f "$TSV" ]]; then
    echo "ERROR: participants.tsv not found: $TSV"
    exit 1
fi

# Read header and existing participant IDs from TSV
HEADER=$(head -n 1 "$TSV")
mapfile -t EXISTING_IDS < <(tail -n +2 "$TSV" | awk -F'\t' '{print $1}' | grep -v '^$')

# Collect participant IDs from sub-* directories on disk
mapfile -t DISK_IDS < <(find "$BIDS_DIR" -maxdepth 1 -type d -name 'sub-*' | xargs -I{} basename {} | sort)

ADDED=0
PRUNED=0

# Determine rows to add
declare -a ROWS_TO_ADD=()
for id in "${DISK_IDS[@]}"; do
    if [[ ! " ${EXISTING_IDS[*]} " =~ " ${id} " ]]; then
        ROWS_TO_ADD+=("$id")
    fi
done

# Determine rows to prune
declare -a ROWS_TO_PRUNE=()
if [[ "$PRUNE" == true ]]; then
    for id in "${EXISTING_IDS[@]}"; do
        if [[ ! " ${DISK_IDS[*]} " =~ " ${id} " ]]; then
            ROWS_TO_PRUNE+=("$id")
        fi
    done
fi

if [[ ${#ROWS_TO_ADD[@]} -eq 0 && ${#ROWS_TO_PRUNE[@]} -eq 0 ]]; then
    echo "participants.tsv is already in sync. No changes needed."
    exit 0
fi

if [[ ${#ROWS_TO_ADD[@]} -gt 0 ]]; then
    echo "Would add:"
    for id in "${ROWS_TO_ADD[@]}"; do
        # Derive column count from header to fill remaining cols with n/a
        NCOLS=$(echo "$HEADER" | awk -F'\t' '{print NF}')
        ROW="$id"
        for (( i=2; i<=NCOLS; i++ )); do
            ROW="$ROW\tn/a"
        done
        echo "  $id"
        if [[ "$DRYRUN" == false ]]; then
            printf "%b\n" "$ROW" >> "$TSV"
            (( ADDED++ )) || true
        fi
    done
fi

if [[ ${#ROWS_TO_PRUNE[@]} -gt 0 ]]; then
    echo "Would remove:"
    for id in "${ROWS_TO_PRUNE[@]}"; do
        echo "  $id"
    done
    if [[ "$DRYRUN" == false ]]; then
        TMP=$(mktemp)
        echo "$HEADER" > "$TMP"
        tail -n +2 "$TSV" | grep -v -f <(printf '%s\n' "${ROWS_TO_PRUNE[@]}" | sed 's/^/^/;s/$/\t/') >> "$TMP" || true
        mv "$TMP" "$TSV"
        PRUNED=${#ROWS_TO_PRUNE[@]}
    fi
fi

if [[ "$DRYRUN" == true ]]; then
    echo ""
    echo "Dry-run: no changes made."
else
    echo ""
    echo "Done. Added: $ADDED, Pruned: $PRUNED"
    echo "  $TSV"
fi
