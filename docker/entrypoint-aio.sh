#!/bin/bash
set -e

PG_DATA="/var/lib/postgresql/data"

# Check if database is initialized
if [ -z "$(ls -A "$PG_DATA")" ]; then
    echo "Initializing PostgreSQL data directory..."
    
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
