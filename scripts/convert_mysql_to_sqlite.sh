#!/bin/bash
#
# convert_mysql_to_sqlite.sh
#
# Load a MySQL-format .sql dump into a MySQL server and export it to a SQLite
# database using db-to-sqlite. In CI, run MySQL via Docker before calling this
# script. Locally, ensure MySQL is running and accessible.
#
# Usage:
#   ./convert_mysql_to_sqlite.sh <input.sql> <output.db> [mysql_database_name]
#
# Environment:
#   MYSQL_HOST     MySQL host (default: localhost)
#   MYSQL_PORT     MySQL port (default: 3306)
#   MYSQL_USER     MySQL user (default: root)
#   MYSQL_PASSWORD MySQL password (default: empty)

set -e

SQL_FILE="$1"
DB_FILE="$2"
# MySQL dumps (e.g. from SQLyog) usually declare their own database via
# "USE `dbname`;" / "CREATE DATABASE ... `dbname`". Honor that name so the
# tables land in the database db-to-sqlite reads from; otherwise fall back
# to the caller-provided name (or "ace_world"). The workflow passes
# "ace_world" as a harmless fallback.
DB_NAME=$(sed -n 's/^USE `\([^`]*\)`.*/\1/p' "$SQL_FILE" 2>/dev/null | head -n1)
if [ -z "$DB_NAME" ]; then
  DB_NAME="${3:-ace_world}"
fi

if [ -z "$SQL_FILE" ] || [ -z "$DB_FILE" ]; then
  echo "Usage: $0 <input.sql> <output.db> [mysql_database_name]"
  exit 1
fi

if [ ! -f "$SQL_FILE" ]; then
  echo "Input file not found: $SQL_FILE"
  exit 1
fi

MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"

MYSQL_OPTS="-h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER"
if [ -n "$MYSQL_PASSWORD" ]; then
  MYSQL_OPTS="$MYSQL_OPTS -p$MYSQL_PASSWORD"
fi

MYSQL_URL="mysql://$MYSQL_USER"
if [ -n "$MYSQL_PASSWORD" ]; then
  MYSQL_URL="${MYSQL_URL}:$MYSQL_PASSWORD"
fi
MYSQL_URL="${MYSQL_URL}@$MYSQL_HOST:$MYSQL_PORT/$DB_NAME"

echo "Creating MySQL database $DB_NAME..."
mysql $MYSQL_OPTS -B -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; CREATE DATABASE \`$DB_NAME\`;"

echo "Loading $SQL_FILE into MySQL..."
mysql $MYSQL_OPTS --database="$DB_NAME" < "$SQL_FILE"

echo "Exporting to SQLite $DB_FILE..."
db-to-sqlite --all "$MYSQL_URL" "$DB_FILE"

# Fail loudly if nothing was exported (db-to-sqlite exits 0 even when it
# finds no tables, e.g. when the dump's USE statement pointed elsewhere).
DB_SIZE=$(wc -c < "$DB_FILE" 2>/dev/null || echo 0)
if [ "$DB_SIZE" -lt 100 ]; then
  echo "ERROR: $DB_FILE is only $DB_SIZE bytes; nothing was exported" >&2
  exit 1
fi

echo "Done: $DB_FILE"
