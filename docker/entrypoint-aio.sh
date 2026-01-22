#!/bin/bash
set -e

PG_DATA="/var/lib/postgresql/data"

# Check if database is initialized
if [ -z "$(ls -A "$PG_DATA")" ]; then
    echo "Initializing PostgreSQL data directory..."
    
    # Init DB
    chown -R postgres:postgres "$PG_DATA"
    su - postgres -c "/usr/lib/postgresql/16/bin/initdb -D $PG_DATA -U imgtag --auth=trust"
    
    echo "Starting temporary PostgreSQL server for setup..."
    su - postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D $PG_DATA -w start"
    
    echo "Creating database and extension..."
    # Create DB if not exists (initdb creates 'postgres' db by default)
    # user 'imgtag' is superuser due to initdb -U imgtag
    su - postgres -c "psql -U imgtag -d postgres -c \"CREATE DATABASE imgtag;\"" || true
    su - postgres -c "psql -U imgtag -d imgtag -c \"CREATE EXTENSION IF NOT EXISTS vector;\""
    
    echo "Stopping temporary PostgreSQL server..."
    su - postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D $PG_DATA -m fast -w stop"
    
    echo "Database initialization complete."
fi

# Ensure permissions are correct (in case volume mount changed them)
chown -R postgres:postgres "$PG_DATA"
chmod 0700 "$PG_DATA"

echo "Starting Supervisord..."
exec /usr/bin/supervisord -c /app/supervisord.conf
