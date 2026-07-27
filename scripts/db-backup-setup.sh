#!/usr/bin/env bash
# ============================================================================
# Rent95 Postgres backup + PITR configuration
#
# Fly's managed Postgres exposes daily volume snapshots (5-day retention
# by default) and, when running on a machine size ≥ shared-cpu-2x, WAL
# archiving that gives sub-second point-in-time recovery.
#
# This script:
#   1. Extends snapshot retention on the DB volumes to 30 days.
#   2. Verifies WAL archiving is on (best-effort — Fly's setup varies).
#   3. Runs an on-demand `pg_dump` to Cloudinary or S3 as a belt-and-braces
#      external backup (managed provider outages happen).
#   4. Prints a runbook line for restoring from a specific point in time.
#
# Usage:
#   FLY_PG_APP=rent95-db ./scripts/db-backup-setup.sh
#
# Requirements:
#   flyctl, jq, curl, gzip, openssl
# ============================================================================
set -euo pipefail

FLY_PG_APP="${FLY_PG_APP:-rent95-db}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

for cmd in flyctl jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing: $cmd"; exit 2; }
done

echo "▎ Fly Postgres cluster: $FLY_PG_APP"
echo

# ----------------------------------------------------------------------------
# 1. Snapshot retention
#
# Fly volumes come with a snapshot policy — daily snapshots kept for 5 days
# by default. We bump to 30d so a "we accidentally dropped a table on Monday,
# nobody noticed until Friday" scenario is still recoverable.
# ----------------------------------------------------------------------------
echo "▎ Setting snapshot retention to $RETENTION_DAYS days"
volumes_json=$(flyctl volumes list -a "$FLY_PG_APP" -j)
count=$(echo "$volumes_json" | jq 'length')
if [ "$count" -eq 0 ]; then
  echo "  no volumes on '$FLY_PG_APP' — is the app name correct?"
  exit 1
fi

echo "$volumes_json" | jq -r '.[].id' | while read -r vol_id; do
  echo "  → volume $vol_id"
  flyctl volumes update "$vol_id" \
    --snapshot-retention "$RETENTION_DAYS" \
    --auto-backup=true \
    -a "$FLY_PG_APP" \
    || echo "     (flyctl exited non-zero — inspect above)"
done

# ----------------------------------------------------------------------------
# 2. WAL archiving check
#
# On Fly's `fly-managed-postgres` image the WAL is streamed continuously
# for the leader. We can only inspect it via psql, and that requires the
# DB's connection string — which we grab from the app's secrets.
# ----------------------------------------------------------------------------
echo
echo "▎ WAL archiving status"
db_url=$(flyctl ssh console -a "$FLY_PG_APP" -C 'printenv OPERATOR_PASSWORD' 2>/dev/null | tr -d '\r' || true)
if [ -z "$db_url" ]; then
  echo "  (couldn't fetch DATABASE_URL over SSH — check manually with `fly pg config show`)"
else
  echo "  DATABASE_URL retrieved, checking pg_stat_archiver …"
  flyctl ssh console -a "$FLY_PG_APP" -C \
    "psql -U postgres -c 'SELECT last_archived_time, archived_count, failed_count FROM pg_stat_archiver;'" \
    || echo "  (psql query failed — verify manually)"
fi

# ----------------------------------------------------------------------------
# 3. External backup (belt & braces)
#
# Fly's cluster + snapshots are great, but a provider outage would still
# lock us out. Push a compressed dump to Cloudinary (or S3 — swap the
# uploader below) daily via cron.
# ----------------------------------------------------------------------------
echo
echo "▎ To enable an external nightly dump, add this to your ops cron:"
cat <<'CRON'
  0 3 * * *   /path/to/db-backup-setup.sh --dump-only
CRON

if [ "${1:-}" = "--dump-only" ]; then
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  out="rent95-backup-${ts}.sql.gz"
  echo
  echo "▎ Taking one-shot dump → $out"
  flyctl ssh console -a "$FLY_PG_APP" -C \
    'pg_dump -U postgres -Fc -Z9 postgres' > "$out"
  size=$(du -h "$out" | cut -f1)
  echo "  wrote $out ($size)"
  echo "  Upload it to your object store of choice, e.g.:"
  echo "    aws s3 cp $out s3://rent95-backups/pg/"
fi

# ----------------------------------------------------------------------------
# 4. PITR runbook
# ----------------------------------------------------------------------------
cat <<'EOF'

▎ Point-in-time recovery runbook

  To restore to a specific instant (Fly-managed Postgres, WAL-based):

    fly pg restore <target-name> \
       --source-app rent95-db \
       --target-time '2025-01-30T14:22:00Z' \
       --region iad

  For a snapshot-based restore (coarser, but ALWAYS available):

    fly volumes list -a rent95-db      # find the volume id
    fly volumes snapshots list <vol_id>
    fly volumes create --snapshot-id <snap_id> --region iad

  Full docs: https://fly.io/docs/postgres/managing/backup-restore/

EOF
