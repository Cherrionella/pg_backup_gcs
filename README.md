# PG Backup GCS

A lightweight Docker image for backing up PostgreSQL databases to Google Cloud Storage (GCS).

---

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
| :--- | :---: | :--- | :--- |
| `PG_CONNECTION_STRING` | **Yes** | - | PostgreSQL connection URL (e.g., `postgres://user:pass@host:5432/db`). |
| `GCS_BUCKET_NAME` | No | `backup` | The name of the GCS bucket to upload to. |

### Secrets (Authentication)

A Google Cloud **Service Account JSON key** is required for GCS uploads.
*   **Recommended**: Mount it using Docker Swarm Secrets at `/run/secrets/service_account`.
*   **Alternative**: Mount it as a file via volumes.

---

## Usage Modes

The container accepts different commands via the entrypoint.

### 1. Backup to GCS
Creates a dump, compresses it and uploads it to GCS.

**Command:** `gcs <path_to_service_account_json>`

The GCS object path will be: `Month_Year/Day/backup-YYYYMMDD-HHMMSS.sql.gz`

### 2. Manual Backup (Stdout)
Dumps the database directly to `stdout`. Useful for piping to local files or other tools.

**Command:** `backup_manual`

---

## Docker Compose / Swarm Example

Recommended usage with [crazy-max/swarm-cronjob](https://github.com/crazy-max/swarm-cronjob)

```yaml
services:
  backup:
    image: pg_backup_gcs:latest
    deploy:
      mode: replicated
      replicas: 0
      restart_policy:
        condition: none
      labels:
        - "swarm.cronjob.enable=true"
        - "swarm.cronjob.schedule=0 * * * *"
        - "swarm.cronjob.skip-running=true"
        - "swarm.cronjob.replicas=1"
    environment:
      # Connection string to the target database
      PG_CONNECTION_STRING: postgres://user:pass@postgres:5432/db
      # (Optional) Custom bucket name
      GCS_BUCKET_NAME: my-custom-backup-bucket
    # Command: "gcs" mode + path to secret
    command:
      - 'gcs'
      - '/run/secrets/service_account'
    secrets:
      - service_account

secrets:
  service_account:
    file: ./gcp-service-account.json
```

---

## Manual Operations Examples

### Perform a local backup:

```sh
docker run --rm \
  -e PG_CONNECTION_STRING="postgres://user:pass@postgres:5432/db" \
  pg_backup_gcs backup_manual | gzip > my_local_backup.sql.gz
```
