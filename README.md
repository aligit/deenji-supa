# Comprehensive Supabase Setup Guide

## Installation

You can install Supabase CLI globally using either npm or bun:

```sh
npm install -g supabase
```

or

```sh
bun install -g supabase
```

## Setting Up Local Supabase for Authentication in Angular (Spartan UI Stack)

This guide walks through configuring a local Supabase instance for authentication in an Angular application built with the Spartan UI stack (Supabase, Prisma, Analog, tRPC, Tailwind, Angular, Nx).

### Prerequisites

- Node.js installed
- Bun or npm installed
- Supabase CLI installed globally (see installation section above)
- Docker installed and running (required for `supabase start`)

### Step 1: Initialize Local Supabase Project

Initialize a local Supabase project in your working directory:

```bash
# Using npm
npx supabase init

# Using bun
bunx supabase init
```

This creates a `supabase/` directory with `config.toml` and migrations directory.

### Step 2: Start Local Supabase Instance

Start the local Supabase services to get your API URL and keys:

```bash
# Using npm
npx supabase start

# Using bun
bunx supabase start
```

For offline use -x edge-runtime,vector,logflare:

```bash
# Using npm
npx supabase start -x edge-runtime,vector,logflare

# Using bun
bunx supabase start -x edge-runtime,vector,logflare
```

You'll receive important connection information:

- API URL: `http://localhost:54321`
- DB URL: `postgresql://postgres:postgres@localhost:54322/postgres`
- Anon key: `<your-anon-key>`
- Service_role key: `<your-service-role-key>`

**Important:** Save the API URL and anon key for your Angular app configuration.

### Step 3: Create a Migration for User Management Schema

Create a new migration file to define the database schema:

```bash
# Using npm
npx supabase migration new create_user_tables

# Using bun
bunx supabase migration new create_user_tables
```

A new migration file will be created at: `supabase/migrations/<timestamp>_create_user_tables.sql`

Edit this file and add the following SQL schema:

```sql
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
```

### Step 4: Apply the Migration to the Local Database

Reset the local database and apply all migrations:

```bash
# Using npm
npx supabase db reset

# Using bun
bunx supabase db reset
```

This process:

1. Drops the existing database
2. Recreates it
3. Applies all migrations in `supabase/migrations/`

## Database Management

### Backup Schema

To backup your database schema (structure only, no data):

```sh
pg_dump "postgresql://postgres:postgres@127.0.0.1:54322/postgres" --schema-only > project_schema.sql
```

## Working with Elasticsearch

### List All Indices

```sh
curl -X GET "http://localhost:9200/_cat/indices?v"
```

### Check a Specific Index

Replace `properties` with your index name:

```sh
curl -X GET "http://localhost:9200/properties?pretty"
```

### Count Documents in Elasticsearch

```sh
curl -X GET "http://localhost:9200/properties/_count?pretty"
```

### Count Records in PostgreSQL

Run in Supabase SQL Editor:

```sql
SELECT COUNT(*) FROM properties;
```

### Geospatial Search (within 5km radius)

```sh
curl -X GET "http://localhost:9200/properties/_search?pretty" -H 'Content-Type: application/json' -d'
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
```

### Full-Text Search

```sh
curl -X GET "http://localhost:9200/properties/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "multi_match": {
      "query": "آپارتمان",
      "fields": ["title", "description", "district"]
    }
  }
}
'
```

## Troubleshooting

Common issues and solutions:

1. **Docker not running**: Ensure Docker is running before executing `supabase start`
2. **Port conflicts**: Check if ports 54321 and 54322 are available
3. **Migration errors**: Verify SQL syntax in migration files

## Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Local Development Guide](https://supabase.com/docs/guides/local-development)
- [Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)
