#!/bin/bash
set -e

PG_DATA="/var/lib/postgresql/data"

# Check if database is initialized by looking for PG_VERSION
if [ ! -s "$PG_DATA/PG_VERSION" ]; then
    echo "Initializing PostgreSQL data directory..."
    # Ensure directory is empty (except for lost+found) to make initdb happy
    find "$PG_DATA" -mindepth 1 -maxdepth 1 -not -name "lost+found" -delete
    
    # Init DB
    chown -R postgres:postgres "$PG_DATA"
    su - postgres -c "/usr/lib/postgresql/16/bin/initdb -D $PG_DATA -U imgtag --auth=trust"
    
    echo "Configuring pg_hba.conf for TCP access..."
    echo "host all all 0.0.0.0/0 trust" >> "$PG_DATA/pg_hba.conf"
    # Allow listening on all interfaces (though we only need localhost for internal app)
    echo "listen_addresses='*'" >> "$PG_DATA/postgresql.conf"

    echo "Starting temporary PostgreSQL server for setup..."
    su - postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D $PG_DATA -w start"
    
    echo "Creating database and extension..."
    # Create DB and Extension
    su - postgres -c "psql -U imgtag -d postgres -c \"CREATE DATABASE imgtag;\"" || true
    su - postgres -c "psql -U imgtag -d imgtag -c \"CREATE EXTENSION IF NOT EXISTS vector;\""
    # Ensure password matches what's in supervisord.conf (though 'trust' ignores it, it's good practice)
    su - postgres -c "psql -U imgtag -d postgres -c \"ALTER USER imgtag WITH PASSWORD 'imgtag';\""
    
    echo "Stopping temporary PostgreSQL server..."
    su - postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D $PG_DATA -m fast -w stop"
    
    echo "Database initialization complete."
fi

# Ensure permissions are correct (in case volume mount changed them)
chown -R postgres:postgres "$PG_DATA"
chmod 0700 "$PG_DATA"

echo "Starting Supervisord..."
exec /usr/bin/supervisord -c /app/supervisord.conf
