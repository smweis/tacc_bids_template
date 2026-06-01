#!/bin/bash
#SBATCH -J dcm2bids-oa_navtrain
#SBATCH -o /work/10989/stevenweisberg/ls6/oa_navtrain/logs/dcm2bids_%x_%j.out
#SBATCH -e /work/10989/stevenweisberg/ls6/oa_navtrain/logs/dcm2bids_%x_%j.err
#SBATCH -p development
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 00:20:00
#SBATCH --mail-type=FAIL
#SBATCH -A DBS26002
#SBATCH --mail-user=stevenweisberg@tacc.utexas.edu

set -euo pipefail

module reset
source /work/10989/stevenweisberg/ls6/oa_navtrain/venvs/dcm2bids/bin/activate

# Move to a stable directory so --re-run cannot delete the job's cwd
cd /work/10989/stevenweisberg/ls6/oa_navtrain

usage() {
    cat <<EOF
Usage:
  $0 <SITE> <SUBJECT_ID> <SESSION_ID> <--copy-template | --use-existing-config> [--validate] [--re-run] [--dry-run]

Required:
  SITE                    One of: UTA, AZ
  SUBJECT_ID              Subject ID WITHOUT the 'sub-' prefix
  SESSION_ID              Session ID WITHOUT the 'ses-' prefix; must be 01 or 02
  --copy-template         Copy the site/session template to the subject/session config, overwriting any existing
  --use-existing-config   Do NOT create/copy a template; require subject/session config to already exist

Optional:
  --validate              Run bids-validator-deno after conversion
  --re-run                Remove existing subject/session BIDS output before running
  --dry-run               Print resolved paths and the command that would run, then exit without doing anything

Examples:
  $0 AZ 1501 01 --copy-template
  $0 AZ 1501 02 --use-existing-config --validate --re-run
  $0 UTA utadev01 01 --copy-template
  $0 AZ 1501 01 --copy-template --dry-run

Important:
  SUBJECT_ID should NOT include 'sub-'.
  SESSION_ID should NOT include 'ses-'.
EOF
}

if [ "$#" -lt 4 ] || [ "$#" -gt 7 ]; then
    usage
    exit 1
fi

SITE="$1"
RAW_SUBID="$2"
SESSION_ID="$3"

if [[ "$RAW_SUBID" == sub-* ]]; then
    echo "ERROR: SUBJECT_ID should NOT include 'sub-'."
    echo "You entered: $RAW_SUBID"
    exit 1
fi

if [[ "$SESSION_ID" == ses-* ]]; then
    echo "ERROR: SESSION_ID should NOT include 'ses-'."
    echo "You entered: $SESSION_ID"
    echo "Use: 01   not   ses-01"
    exit 1
fi

if [[ "$SESSION_ID" != "01" && "$SESSION_ID" != "02" ]]; then
    echo "ERROR: SESSION_ID must be exactly 01 or 02."
    echo "You entered: $SESSION_ID"
    exit 1
fi

SUBID="sub-$RAW_SUBID"
SESID="ses-$SESSION_ID"

VALIDATE=false
RERUN=false
DRYRUN=false
CONFIG_MODE=""

shift 3
for arg in "$@"; do
    case "$arg" in
        --validate)
            VALIDATE=true
            ;;
        --re-run)
            RERUN=true
            ;;
        --dry-run)
            DRYRUN=true
            ;;
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
    echo "ERROR: You must specify exactly one of:"
    echo "  --copy-template"
    echo "  --use-existing-config"
    usage
    exit 1
fi

BASE_DIR=/work/10989/stevenweisberg/ls6/oa_navtrain
CONFIG_DIR=$BASE_DIR/configs
LOG_DIR=$BASE_DIR/logs

TMP_ROOT=$BASE_DIR/tmp_dcm2bids
SUB_TMP_DIR=$TMP_ROOT/${SITE}_${SUBID}_${SESID}

case "$SITE" in
    UTA)
        BIDS_DIR=$BASE_DIR/bids_UTA
        TEMPLATE_JSON=$CONFIG_DIR/dcm2bids_config_site-UTA_ses-${SESSION_ID}_template.json
        ;;
    AZ)
        BIDS_DIR=$BASE_DIR/bids_AZ
        TEMPLATE_JSON=$CONFIG_DIR/dcm2bids_config_site-AZ_ses-${SESSION_ID}_template.json
        ;;
    *)
        echo "ERROR: SITE must be one of: UTA, AZ"
        exit 1
        ;;
esac

SOURCEDATA_DIR=$BIDS_DIR/sourcedata
CONFIG_JSON=$CONFIG_DIR/dcm2bids_config_site-${SITE}_sub-${RAW_SUBID}_ses-${SESSION_ID}.json
SUB_OUT_DIR=$BIDS_DIR/$SUBID/$SESID

mkdir -p "$LOG_DIR"
mkdir -p "$TMP_ROOT"
mkdir -p "$CONFIG_DIR"

if [ -d "$SOURCEDATA_DIR/$SUBID/$SESID" ]; then
    SOURCE_SUBDIR="$SOURCEDATA_DIR/$SUBID/$SESID"
elif [ -d "$SOURCEDATA_DIR/$RAW_SUBID/$SESSION_ID" ]; then
    SOURCE_SUBDIR="$SOURCEDATA_DIR/$RAW_SUBID/$SESSION_ID"
else
    echo "ERROR: source directory not found."
    echo "Checked:"
    echo "  $SOURCEDATA_DIR/$SUBID/$SESID"
    echo "  $SOURCEDATA_DIR/$RAW_SUBID/$SESSION_ID"
    exit 1
fi

echo "=============================="
echo "SITE:         $SITE"
echo "RAW SUBID:    $RAW_SUBID"
echo "SUBID:        $SUBID"
echo "SESSION_ID:   $SESSION_ID"
echo "SESID:        $SESID"
echo "BIDS:         $BIDS_DIR"
echo "SOURCE:       $SOURCE_SUBDIR"
echo "CONFIG MODE:  $CONFIG_MODE"
echo "CONFIG:       $CONFIG_JSON"
echo "TEMPLATE:     $TEMPLATE_JSON"
echo "TMP ROOT:     $SUB_TMP_DIR"
echo "VALIDATE:     $VALIDATE"
echo "RE-RUN:       $RERUN"
echo "DRY-RUN:      $DRYRUN"
echo "=============================="

if [ "$DRYRUN" = true ]; then
    echo ""
    echo "DRY-RUN: would execute:"
    echo "  dcm2bids -d $SOURCE_SUBDIR -p $RAW_SUBID -s $SESSION_ID -c $CONFIG_JSON -o $BIDS_DIR"
    if [ "$VALIDATE" = true ]; then
        echo "  bids-validator-deno $BIDS_DIR"
    fi
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
            echo "ERROR: subject/session config file not found: $CONFIG_JSON"
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

echo "Done: $SITE $SUBID $SESID"
