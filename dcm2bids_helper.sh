#!/bin/bash

set -euo pipefail

DICOM_DIR="/work/10989/stevenweisberg/ls6/oa_navtrain/bids_AZ/sourcedata/sub-1603/ses-02"
HELPER_DIR="$SCRATCH/oa_navtrain/dcm2bids_helper_AZ_ses02"

source /work/10989/stevenweisberg/ls6/oa_navtrain/venvs/dcm2bids/bin/activate

mkdir -p "$HELPER_DIR"

echo "Running dcm2bids_helper on:"
echo "  $DICOM_DIR"
echo
echo "Writing helper output to:"
echo "  $HELPER_DIR/tmp_dcm2bids/helper/"
echo

dcm2bids_helper \
  -d "$DICOM_DIR" \
  -o "$HELPER_DIR" \
  --force

echo
echo "Done."
echo "Inspect JSON sidecars here:"
echo "  $HELPER_DIR/tmp_dcm2bids/helper/"
