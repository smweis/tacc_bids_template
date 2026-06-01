#!/bin/bash
#SBATCH -J dcm2bids
#SBATCH -o logs/dcm2bids_%x_%j.out
#SBATCH -e logs/dcm2bids_%x_%j.err
#SBATCH -p development
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 00:20:00
#SBATCH --mail-type=FAIL
#SBATCH -A ACCOUNT_CODE
#SBATCH --mail-user=YOUR_EMAIL@domain.com

# Submit from the BIDS root directory:
#   sbatch code/run_dcm2bids.sh <SUBJECT_ID> <SESSION_ID> <--copy-template | --use-existing-config> [--validate] [--re-run] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIDS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$BIDS_DIR")"

module reset
source "$PROJECT_DIR/venvs/dcm2bids/bin/activate"

usage() {
    cat <<EOF
Usage:
  sbatch code/$0 <SUBJECT_ID> <SESSION_ID> <--copy-template | --use-existing-config> [--validate] [--re-run] [--dry-run]

Required:
  SUBJECT_ID              Subject ID WITHOUT the 'sub-' prefix
  SESSION_ID              Session ID WITHOUT the 'ses-' prefix; must be 01 or 02
  --copy-template         Copy the session template to the subject/session config, overwriting any existing
  --use-existing-config   Do NOT copy a template; require subject/session config to already exist

Optional:
  --validate              Run bids-validator-deno after conversion
  --re-run                Remove existing subject/session BIDS output before running
  --dry-run               Print resolved paths and the command that would run, then exit

Examples:
  sbatch code/$0 1501 01 --copy-template
  sbatch code/$0 1501 02 --use-existing-config --validate --re-run
  sbatch code/$0 1501 01 --copy-template --dry-run

Important:
  SUBJECT_ID should NOT include 'sub-'.
  SESSION_ID should NOT include 'ses-'.
  Run sbatch from the BIDS root directory so logs/ resolves correctly.
EOF
}

if [ "$#" -lt 3 ] || [ "$#" -gt 6 ]; then
    usage
    exit 1
fi

RAW_SUBID="$1"
SESSION_ID="$2"

if [[ "$RAW_SUBID" == sub-* ]]; then
    echo "ERROR: SUBJECT_ID should NOT include 'sub-'. You entered: $RAW_SUBID"
    exit 1
fi

if [[ "$SESSION_ID" == ses-* ]]; then
    echo "ERROR: SESSION_ID should NOT include 'ses-'. Use: 01  not  ses-01"
    exit 1
fi

if [[ "$SESSION_ID" != "01" && "$SESSION_ID" != "02" ]]; then
    echo "ERROR: SESSION_ID must be exactly 01 or 02. You entered: $SESSION_ID"
    exit 1
fi

SUBID="sub-$RAW_SUBID"
SESID="ses-$SESSION_ID"

VALIDATE=false
RERUN=false
DRYRUN=false
CONFIG_MODE=""

shift 2
for arg in "$@"; do
    case "$arg" in
        --validate)         VALIDATE=true ;;
        --re-run)           RERUN=true ;;
        --dry-run)          DRYRUN=true ;;
        --copy-template)
            if [ -n "$CONFIG_MODE" ]; then
                echo "ERROR: Choose only one of --copy-template or --use-existing-config"
                exit 1
            fi
            CONFIG_MODE="copy-template"
            ;;
        --use-existing-config)
            if [ -n "$CONFIG_MODE" ]; then
                echo "ERROR: Choose only one of --copy-template or --use-existing-config"
                exit 1
            fi
            CONFIG_MODE="use-existing-config"
            ;;
        *)
            echo "ERROR: unknown option: $arg"
            usage
            exit 1
            ;;
    esac
done

if [ -z "$CONFIG_MODE" ]; then
    echo "ERROR: You must specify exactly one of --copy-template or --use-existing-config"
    usage
    exit 1
fi

CONFIG_DIR="$BIDS_DIR/code/configs"
TMP_ROOT="$BIDS_DIR/tmp_dcm2bids"
SUB_TMP_DIR="$TMP_ROOT/${SUBID}_${SESID}"

TEMPLATE_JSON="$CONFIG_DIR/dcm2bids_config_ses-${SESSION_ID}_template.json"
CONFIG_JSON="$CONFIG_DIR/dcm2bids_config_sub-${RAW_SUBID}_ses-${SESSION_ID}.json"
SOURCEDATA_DIR="$BIDS_DIR/sourcedata"
SUB_OUT_DIR="$BIDS_DIR/$SUBID/$SESID"

mkdir -p "$BIDS_DIR/logs"
mkdir -p "$TMP_ROOT"

if [ -d "$SOURCEDATA_DIR/$SUBID/$SESID" ]; then
    SOURCE_SUBDIR="$SOURCEDATA_DIR/$SUBID/$SESID"
elif [ -d "$SOURCEDATA_DIR/$RAW_SUBID/$SESSION_ID" ]; then
    SOURCE_SUBDIR="$SOURCEDATA_DIR/$RAW_SUBID/$SESSION_ID"
else
    echo "ERROR: source directory not found."
    echo "  Checked: $SOURCEDATA_DIR/$SUBID/$SESID"
    echo "  Checked: $SOURCEDATA_DIR/$RAW_SUBID/$SESSION_ID"
    exit 1
fi

echo "=============================="
echo "BIDS DIR:     $BIDS_DIR"
echo "RAW SUBID:    $RAW_SUBID"
echo "SUBID:        $SUBID"
echo "SESSION_ID:   $SESSION_ID"
echo "SESID:        $SESID"
echo "SOURCE:       $SOURCE_SUBDIR"
echo "CONFIG MODE:  $CONFIG_MODE"
echo "CONFIG:       $CONFIG_JSON"
echo "TEMPLATE:     $TEMPLATE_JSON"
echo "VALIDATE:     $VALIDATE"
echo "RE-RUN:       $RERUN"
echo "DRY-RUN:      $DRYRUN"
echo "=============================="

if [ "$DRYRUN" = true ]; then
    echo ""
    echo "DRY-RUN: would execute:"
    echo "  dcm2bids -d $SOURCE_SUBDIR -p $RAW_SUBID -s $SESSION_ID -c $CONFIG_JSON -o $BIDS_DIR"
    [ "$VALIDATE" = true ] && echo "  bids-validator-deno $BIDS_DIR"
    echo ""
    echo "No files were created or modified."
    exit 0
fi

case "$CONFIG_MODE" in
    copy-template)
        if [ ! -f "$TEMPLATE_JSON" ]; then
            echo "ERROR: template config not found: $TEMPLATE_JSON"
            exit 1
        fi
        cp "$TEMPLATE_JSON" "$CONFIG_JSON"
        echo "Copied template to subject/session config (clobbering any existing):"
        echo "  $CONFIG_JSON"
        ;;
    use-existing-config)
        if [ ! -f "$CONFIG_JSON" ]; then
            echo "ERROR: subject/session config not found: $CONFIG_JSON"
            echo "You chose --use-existing-config, so no template was copied."
            exit 1
        fi
        ;;
esac

if [ "$RERUN" = true ]; then
    echo "Removing existing BIDS output for $SUBID $SESID"
    rm -rf "$SUB_OUT_DIR"
fi

rm -rf "$SUB_TMP_DIR"
mkdir -p "$SUB_TMP_DIR"

DCM2BIDS_CMD=(
    dcm2bids
    -d "$SOURCE_SUBDIR"
    -p "$RAW_SUBID"
    -s "$SESSION_ID"
    -c "$CONFIG_JSON"
    -o "$BIDS_DIR"
)

echo "Running: ${DCM2BIDS_CMD[*]}"
"${DCM2BIDS_CMD[@]}"

rm -rf "$SUB_TMP_DIR"
rm -rf "$BIDS_DIR/tmp_dcm2bids"

if [ "$VALIDATE" = true ]; then
    echo "Running BIDS validator on $BIDS_DIR"
    bids-validator-deno "$BIDS_DIR"
fi

echo "Done: $SUBID $SESID"
