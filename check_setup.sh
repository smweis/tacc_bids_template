#!/bin/bash

# Verifies that the expected project structure, containers, venvs, configs,
# and license file are in place on TACC before running any pipeline scripts.

set -uo pipefail

BASE="/work/10989/stevenweisberg/ls6/oa_navtrain"

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
echo "  oa_navtrain setup check"
echo "  Base: $BASE"
echo "================================================"
echo ""

echo "--- Project directory ---"
check "Project root"         "$BASE"                                        dir

echo ""
echo "--- BIDS datasets ---"
check "bids_AZ"              "$BASE/bids_AZ"                                dir
check "bids_AZ/sourcedata"   "$BASE/bids_AZ/sourcedata"                     dir
check "bids_UTA"             "$BASE/bids_UTA"                               dir
check "bids_UTA/sourcedata"  "$BASE/bids_UTA/sourcedata"                    dir

echo ""
echo "--- Containers ---"
check "fMRIPrep 25.2.5"      "$BASE/containers/fmriprep-25.2.5.sif"        file
check "MRIQC 24.0.2"         "$BASE/containers/mriqc-24.0.2.sif"           file

echo ""
echo "--- Python virtual environments ---"
check "dcm2bids venv"        "$BASE/venvs/dcm2bids/bin/activate"            file
check "pydeface venv"        "$BASE/venvs/pydeface/bin/activate"            file

echo ""
echo "--- FreeSurfer license ---"
check "license.txt"          "$BASE/license.txt"                            file

echo ""
echo "--- Config directory ---"
check "configs/"             "$BASE/configs"                                dir

echo ""
echo "--- dcm2bids config templates ---"
check "AZ ses-01 template"   "$BASE/configs/dcm2bids_config_site-AZ_ses-01_template.json"  file
check "AZ ses-02 template"   "$BASE/configs/dcm2bids_config_site-AZ_ses-02_template.json"  file
check "UTA ses-01 template"  "$BASE/configs/dcm2bids_config_site-UTA_ses-01_template.json" file
check "UTA ses-02 template"  "$BASE/configs/dcm2bids_config_site-UTA_ses-02_template.json" file

echo ""
echo "--- Logs directory ---"
check "logs/"                "$BASE/logs"                                   dir

echo ""
echo "--- Zipped DICOMs directory ---"
check "zipped_dicoms/"       "$BASE/zipped_dicoms"                          dir

echo ""
echo "================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "================================================"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
