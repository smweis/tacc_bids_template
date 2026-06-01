#!/bin/bash

# Verifies that the expected project structure, containers, venvs, configs,
# and license file are in place on TACC before running any pipeline scripts.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIDS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$BIDS_DIR")"

PASS=0
FAIL=0

check() {
    local label="$1"
    local path="$2"
    local kind="$3"   # "file" or "dir"

    if [[ "$kind" == "dir" && -d "$path" ]]; then
        echo "  [OK]   $label"
        (( PASS++ )) || true
    elif [[ "$kind" == "file" && -f "$path" ]]; then
        echo "  [OK]   $label"
        (( PASS++ )) || true
    else
        echo "  [FAIL] $label"
        echo "         expected $kind: $path"
        (( FAIL++ )) || true
    fi
}

echo "================================================"
echo "  Setup check"
echo "  BIDS dir:    $BIDS_DIR"
echo "  Project dir: $PROJECT_DIR"
echo "================================================"
echo ""

echo "--- BIDS dataset ---"
check "BIDS root"            "$BIDS_DIR"                                          dir
check "sourcedata/"          "$BIDS_DIR/sourcedata"                               dir
check "dataset_description"  "$BIDS_DIR/dataset_description.json"                 file
check "participants.tsv"     "$BIDS_DIR/participants.tsv"                         file

echo ""
echo "--- Pipeline scripts ---"
check "code/"                "$BIDS_DIR/code"                                     dir
check "code/configs/"        "$BIDS_DIR/code/configs"                             dir

echo ""
echo "--- dcm2bids config templates ---"
check "ses-01 template"      "$BIDS_DIR/code/configs/dcm2bids_config_ses-01_template.json"  file
check "ses-02 template"      "$BIDS_DIR/code/configs/dcm2bids_config_ses-02_template.json"  file

echo ""
echo "--- Project-level resources (in $PROJECT_DIR) ---"
check "containers/"          "$PROJECT_DIR/containers"                            dir
check "fMRIPrep 25.2.5"      "$PROJECT_DIR/containers/fmriprep-25.2.5.sif"       file
check "MRIQC 24.0.2"         "$PROJECT_DIR/containers/mriqc-24.0.2.sif"          file
check "dcm2bids venv"        "$PROJECT_DIR/venvs/dcm2bids/bin/activate"          file
check "pydeface venv"        "$PROJECT_DIR/venvs/pydeface/bin/activate"          file
check "FreeSurfer license"   "$PROJECT_DIR/license.txt"                          file
check "zipped_dicoms/"       "$PROJECT_DIR/zipped_dicoms"                        dir

echo ""
echo "================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "================================================"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
