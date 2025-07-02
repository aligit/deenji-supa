Quick Guide: Accessing Our Supabase Database

This short guide explains how to connect to our Supabase database using an SSH tunnel. This approach allows secure access to the database without exposing it directly to the internet.
Method 1: Using Terminal with psql
Step 1: Install PostgreSQL Client

On Ubuntu/Debian:

sudo apt update
sudo apt install postgresql-client

On Windows:

    Download the PostgreSQL installer from postgresql.org
    During installation, you only need the command-line tools

Step 2: Create SSH Tunnel

Open a terminal window and run:

ssh -L 5432:localhost:54322 root@185.208.174.152

This creates a secure tunnel from your local port 5432 to the server’s port 54322.

Keep this terminal window open as long as you need the connection!
Step 3: Connect to Database

In a new terminal window, connect to the database:

psql "postgresql://postgres:postgres@localhost:5432/postgres"

You’re now connected! Try a test query:

SELECT count(\*) FROM properties;

Method 2: Using DBeaver (GUI Option)

DBeaver is a user-friendly database management tool with a graphical interface.
Step 1: Install DBeaver

Download and install from dbeaver.io
Step 2: Create SSH Tunnel (same as above)

ssh -L 5432:localhost:54322 root@185.208.174.152

Step 3: Configure DBeaver Connection

    Open DBeaver
    Click “New Database Connection”
    Select PostgreSQL
    Enter these settings:
        Host: localhost
        Port: 5432
        Database: postgres
        Username: postgres
        Password: postgres
    Test the connection and save

Step 4: Use DBeaver

    Browse tables in the database navigator
    Execute SQL queries in the SQL editor
    View and edit data visually

Useful psql Commands

Once connected with psql, try these commands:

\dt # List all tables
\d table_name # Describe a table's structure
\x # Toggle expanded display
\timing # Toggle query execution time display
\q # Quit psql

Running SQL Queries

Example queries:

-- Count properties
SELECT COUNT(\*) FROM properties;

-- View recent properties
SELECT id, title, price, created_at
FROM properties
ORDER BY created_at DESC
LIMIT 10;

-- Property type distribution
SELECT type, COUNT(_)
FROM properties
GROUP BY type
ORDER BY COUNT(_) DESC;

Troubleshooting

    “Connection refused” error: Make sure the SSH tunnel is active in a separate terminal window

    “Authentication failed” error: Double-check the username and password

    Port already in use: If port 5432 is in use, try a different local port:

    ssh -L 5433:localhost:54322 root@185.208.174.152

    Then connect using:

    psql "postgresql://postgres:postgres@localhost:5433/postgres"

    SSH key issues: If using SSH keys, you may need to specify the key file:

    ssh -i /path/to/key -L 5432:localhost:54322 root@185.208.174.152

Let me know if you need any help with database access!
