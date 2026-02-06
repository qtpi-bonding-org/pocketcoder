#!/bin/sh

# Start helper to check for admins and create one if missing
if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
    echo "🔍 Checking for superuser..."
    # Check if we need to create a superuser. 
    # Attempt to create (upsert). This command updates if exists, creates if not.
    /pb/pocketbase superuser upsert "$ADMIN_EMAIL" "$ADMIN_PASSWORD"
    echo "✅ Superuser configured."
fi

# Execute the main command
exec "$@"
