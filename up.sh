#!/usr/bin/env bash

# standard bash safety flags
set -o errexit          # Exit on error
set -o nounset          # Fail on unset variables
set -o pipefail         # Fail if any command in a pipe fails

script_usage() {
    cat << EOF
Usage:
    ${BASH_SOURCE[0]} gcs <KEYFILE>       Run pg dump to GCS
    ${BASH_SOURCE[0]} backup_manual       Run pg dump to stdout (manual mode)
EOF
}

BACKUP_DIR=/backups

check_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        if ! mkdir -p "$BACKUP_DIR"; then
            echo "Something went wrong while creating $BACKUP_DIR"
            exit 1
        fi
    fi
}

check_connection_string() {
    if [[ -z "${PG_CONNECTION_STRING-}" ]]; then
        echo "Error: PG_CONNECTION_STRING environment variable is not set." >&2
        exit 1
    fi
}

check_service_account_file() {
    local file="${1-}"
    if [[ -z "$file" ]]; then
        echo "Error: Service account key file argument is missing." >&2
        exit 1
    fi
    if [[ ! -f "$file" ]]; then
        echo "Error: Service account key file not found at: $file" >&2
        exit 1
    fi
}

dump_stdout() {
    check_connection_string
    pg_dump -d "$PG_CONNECTION_STRING"
}

backup_gcs() {
    check_backup_dir
    check_connection_string
    local secret_file="${1-}"
    check_service_account_file "$secret_file"

    local bucket_name="${GCS_BUCKET_NAME:-backup}"

    local target_filename dump_filename
    dump_filename=$(date +backup-%Y%m%d-%H%M%S.sql.gz)
    target_filename=$(date +%b_%y/%d/${dump_filename})

    echo "Creating backup: $dump_filename"

    source "$(dirname "${BASH_SOURCE[0]}")/gcs.sh"

    pg_dump -d "$PG_CONNECTION_STRING" | gzip -9 > "${BACKUP_DIR}/${dump_filename}"

    echo "Uploading to GCS..."
    upload "${bucket_name}" "${BACKUP_DIR}/${dump_filename}" "$target_filename" "$secret_file"

    echo "Done."
}

# --- Entrypoint Router ---
if [[ $# -eq 0 ]]; then
    script_usage
    exit 0
fi

case "$1" in
    backup_manual)
        dump_stdout
        ;;
    gcs)
        shift
        if [[ $# -gt 0 ]]; then
            backup_gcs "$1"
        else
            echo "Error: Missing keyfile argument." >&2
            echo "Usage: ${BASH_SOURCE[0]} pg <KEYFILE>" >&2
            exit 1
        fi
        ;;
    -h|--help)
        script_usage
        ;;
    *)
        echo "Unknown command: $1" >&2
        script_usage
        exit 1
        ;;
esac