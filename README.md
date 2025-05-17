Comprehensive Supabase Setup Guide
Installation

You can install Supabase CLI globally using either npm or bun:

sh

npm install -g supabase

or

sh

bun install -g supabase

Setting Up Local Supabase for Authentication in Angular (Spartan UI Stack)

This guide walks through configuring a local Supabase instance for authentication in an Angular application built with the Spartan UI stack (Supabase, Prisma, Analog, tRPC, Tailwind, Angular, Nx).
Prerequisites

    Node.js installed
    Bun or npm installed
    Supabase CLI installed globally (see installation section above)
    Docker installed and running (required for supabase start)

Step 1: Initialize Local Supabase Project

Initialize a local Supabase project in your working directory:

bash

# Using npm

npx supabase init

# Using bun

bunx supabase init

This creates a supabase/ directory with config.toml and migrations directory.
Step 2: Start Local Supabase Instance

Start the local Supabase services to get your API URL and keys:

bash

# Using npm

npx supabase start

# Using bun

bunx supabase start

For offline use -x edge-runtime,vector,logflare:

bash

# Using npm

npx supabase start -x edge-runtime,vector,logflare

# Using bun

bunx supabase start -x edge-runtime,vector,logflare

You'll receive important connection information:

    API URL: http://localhost:54321
    DB URL: postgresql://postgres:postgres@localhost:54322/postgres
    Anon key: <your-anon-key>
    Service_role key: <your-service-role-key>

Important: Save the API URL and anon key for your Angular app configuration.
Step 3: Create a Migration for User Management Schema

Create a new migration file to define the database schema:

bash

# Using npm

npx supabase migration new create_user_tables

# Using bun

bunx supabase migration new create_user_tables

A new migration file will be created at: supabase/migrations/<timestamp>\_create_user_tables.sql

Edit this file and add the following SQL schema:

sql

-- Create profiles table
create table profiles (
id uuid references auth.users on delete cascade not null primary key,
updated_at timestamp with time zone,
username text unique,
avatar_url text,
website text,
constraint username_length check (char_length(username) >= 3)
);

-- Enable Row-Level Security (RLS)
alter table profiles enable row level security;

-- Set up RLS policies
create policy "Public profiles are viewable by everyone."
on profiles for select
using (true);

create policy "Users can insert their own profile."
on profiles for insert
with check (auth.uid() = id);

create policy "Users can update own profile."
on profiles for update
using (auth.uid() = id);

-- Set up Storage for avatars
insert into storage.buckets (id, name)
values ('avatars', 'avatars')
on conflict (id) do nothing;

create policy "Avatar images are publicly accessible."
on storage.objects for select
using (bucket_id = 'avatars');

create policy "Users can upload an avatar."
on storage.objects for insert
with check (bucket_id = 'avatars' and auth.uid() = owner);

create policy "Users can update their avatar."
on storage.objects for update
with check (bucket_id = 'avatars' and auth.uid() = owner);

Step 4: Apply the Migration to the Local Database

Reset the local database and apply all migrations:

bash

# Using npm

npx supabase db reset

# Using bun

bunx supabase db reset

This process:

    Drops the existing database
    Recreates it
    Applies all migrations in supabase/migrations/

Database Management
Backup Schema

To backup your database schema (structure only, no data):

sh

pg_dump "postgresql://postgres:postgres@127.0.0.1:54322/postgres" --schema-only > project_schema.sql

Database Schema Dumps
Minimal Table Structure Summary

Get a quick overview of your table structures with column names and types:

bash

# Connect and run a query to get just table structure

docker exec supabase_db_deenji-supabase psql -U postgres postgres -c "
SELECT
t.table_name,
string_agg(
c.column_name || ' ' || c.data_type ||
CASE
WHEN c.is_nullable = 'NO' THEN ' NOT NULL'
ELSE ''
END,
E',\n '
) as columns
FROM information_schema.tables t
JOIN information_schema.columns c ON t.table_name = c.table_name
WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
GROUP BY t.table_name
ORDER BY t.table_name;
" > table_summary.txt

Complete Schema Dump Alternatives

Option 1: Minimal CREATE TABLE statements only

bash

## Only table names and columns

```sh
docker exec supabase_db_deenji-supabase psql -U postgres -d postgres -t -c "
SELECT table_name || '(' ||
  string_agg(column_name || ' ' || data_type, ', ' ORDER BY ordinal_position) || ')'
FROM information_schema.columns
WHERE table_schema = 'public'
GROUP BY table_name
ORDER BY table_name;" > minimal_tables.sql
```

## Minimal table dump - just CREATE TABLE statements

```sh
docker exec supabase_db_deenji-supabase pg_dump -U postgres \
 -s -n public --no-owner --no-privileges --no-comments \
 postgres > minimal_tables.sql
```

Option 2: Complete public schema with all objects

bash

## Complete schema dump including tables, indexes, constraints, etc.

docker exec supabase_db_deenji-supabase pg_dump -U postgres \
 -n public -s postgres > complete_public_schema.sql

Option 3: Full database schema (all schemas)

bash

## Complete database schema including auth, storage, etc.

docker exec supabase_db_deenji-supabase pg_dump -U postgres \
 -s postgres > full_database_schema.sql

Interactive Database Exploration

bash

# Connect to the database interactively

```sh
docker exec -it supabase_db_deenji-supabase psql -U postgres postgres

# Once connected, use these commands:

# \dt # List all tables in current schema

# \dt public.\* # List tables in public schema

# \d+ table_name # Describe specific table with details

# \dn # List all schemas

# \l # List all databases
```

## Update real estate properties

When crawling divar the type remains NULL. Use the following function to fix that:

```sql
UPDATE public.properties
SET type =
    CASE
        -- 1. Check for VILA
        WHEN title ILIKE '%ویلا%' OR description ILIKE '%ویلا%' OR
             title ILIKE '%ویلایی%' OR description ILIKE '%ویلایی%'
            THEN 'vila'

        -- 2. Check for APARTMENT (if not already classified as vila)
        WHEN title ILIKE '%آپارتمان%' OR description ILIKE '%آپارتمان%' OR
             title ILIKE '%اپارتمان%' OR description ILIKE '%اپارتمان%' OR -- Common typo/alternative
             title ILIKE '%برج%' OR description ILIKE '%برج%' OR
             title ILIKE '%مجتمع مسکونی%' OR description ILIKE '%مجتمع مسکونی%' OR
             ( (title ILIKE '%واحد%' OR description ILIKE '%واحد%') AND -- "واحد" is a strong indicator for apartment
               NOT (title ILIKE '%ویلا%' OR description ILIKE '%ویلا%') AND -- but ensure it's not a "واحد ویلایی"
               NOT (title ILIKE '%زمین%' OR description ILIKE '%زمین%') -- and not "واحد زمین" (less likely)
             )
            THEN 'apartment'

        -- 3. Check for LAND (if not already classified as vila or apartment)
        WHEN title ILIKE '%زمین%' OR description ILIKE '%زمین%' OR
             title ILIKE '%قطعه زمین%' OR description ILIKE '%قطعه زمین%' OR
             title ILIKE '%قطعه%' OR description ILIKE '%قطعه%' OR -- Often used with زمین
             ( (title ILIKE '%باغ%' OR description ILIKE '%باغ%') AND
               NOT (title ILIKE '%ویلا%' OR description ILIKE '%ویلا%') AND
               NOT (title ILIKE '%آپارتمان%' OR description ILIKE '%آپارتمان%') AND
               NOT (title ILIKE '%اپارتمان%' OR description ILIKE '%اپارتمان%')
             ) OR
             ( (title ILIKE '%باغچه%' OR description ILIKE '%باغچه%') AND
               NOT (title ILIKE '%ویلا%' OR description ILIKE '%ویلا%') AND
               NOT (title ILIKE '%آپارتمان%' OR description ILIKE '%آپارتمان%') AND
               NOT (title ILIKE '%اپارتمان%' OR description ILIKE '%اپارتمان%')
             )
            THEN 'land'

        -- If none of the above, keep it NULL (or set to 'unknown' if you prefer)
        ELSE NULL
    END
WHERE type IS NULL; -- Only update rows where type is currently NULL
```

# Working with Elasticsearch

List All Indices

sh

curl -X GET "http://localhost:9200/\_cat/indices?v"

Check a Specific Index

Replace properties with your index name:

sh

curl -X GET "http://localhost:9200/properties?pretty"

Count Documents in Elasticsearch

sh

curl -X GET "http://localhost:9200/properties/\_count?pretty"

Count Records in PostgreSQL

Run in Supabase SQL Editor:

sql

SELECT COUNT(\*) FROM properties;

Geospatial Search (within 5km radius)

sh

curl -X GET "http://localhost:9200/properties/\_search?pretty" -H 'Content-Type: application/json' -d'
{
"query": {
"geo_distance": {
"distance": "5km",
"location": {
"lat": 35.7219,
"lon": 51.3347
}
}
}
}
'

Full-Text Search

sh

curl -X GET "http://localhost:9200/properties/\_search?pretty" -H 'Content-Type: application/json' -d'
{
"query": {
"multi_match": {
"query": "آپارتمان",
"fields": ["title", "description", "district"]
}
}
}
'

Troubleshooting

Common issues and solutions:

    Docker not running: Ensure Docker is running before executing supabase start
    Port conflicts: Check if ports 54321 and 54322 are available
    Migration errors: Verify SQL syntax in migration files

Additional Resources

    Supabase Documentation
    Supabase Local Development Guide
    Row Level Security Guide
