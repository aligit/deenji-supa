Below is a documented guide based on the steps we’ve worked through to set up your local Supabase instance and integrate it with your Angular app using the Spartan UI and Analog ecosystem. I’ve included the commands we used, cleaned up your additional terminal output, and added some useful commands for future reference. This assumes you’ve already initialized your Angular app and Supabase basic integration as per your original question.
Setting Up Local Supabase Authentication with Angular (Spartan UI / Analog)
This guide demonstrates how to configure a local Supabase instance for authentication in an Angular app built with the Spartan UI stack (Supabase, Prisma, Analog, tRPC, Tailwind, Angular, Nx). It’s tailored to your scenario where you’re running Supabase locally instead of using a remote supabase.com project.
Prerequisites
Node.js and Bun installed (since you’re using bunx).
Supabase CLI installed globally or available via bunx supabase.
An Angular app initialized with @supabase/supabase-js installed (npm install @supabase/supabase-js).
Docker installed and running (required for supabase start).
Step-by-Step Setup

1. Initialize Local Supabase Project
   If not already done, initialize a local Supabase project in your working directory (e.g., ~/work-public/deenji-supabase).
   bash
   bunx supabase init
   Creates a supabase/ directory with config.toml and [migrations](https://supabase.com/docs/guides/local-development/)/.
   Output: Supabase project initialized.
2. Start Local Supabase Instance
   Start the local Supabase services to get your API URL and keys.
   bash
   bunx supabase start
   Output includes:
   API URL: http://localhost:54321
   DB URL: postgresql://postgres:postgres@localhost:54322/postgres
   anon key: <your-anon-key>
   service_role key: <your-service-role-key>
   Save the API URL and anon key for your Angular app.
3. Create a Migration for the User Management Schema
   Create a new migration file to define the database schema (e.g., the "User Management Starter" schema).
   bash
   bunx supabase migration new create_user_tables
   Output: Created new migration at supabase/migrations/<timestamp>\_create_user_tables.sql
   Example timestamped file: supabase/migrations/20250227063959_create_user_tables.sql.
   Edit the migration file (supabase/migrations/<timestamp>\_create_user_tables.sql) and add the schema SQL:
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
with check (bucket_id = 'avatars' and auth.uid() = owner); 4. Apply the Migration to the Local Database
Reset the local database and apply all migrations.
bash
bunx supabase db reset
Output:
Resetting local database...
Recreating database...
Initialising schema...
Seeding globals from roles.sql...
Applying migration <timestamp>\_create_user_tables.sql...
WARN: no files matched pattern: supabase/seed.sql
Restarting containers...
Finished supabase db reset on branch master.
This drops the existing database, recreates it, and applies all migrations in `sup

# Backup schema

```sh
pg_dump "postgresql://postgres:postgres@127.0.0.1:54322/postgres" --schema-only > deenji_schema.sql
```

# Elasticsearch

## List all indices

```sh
curl -X GET "http://localhost:9200/_cat/indices?v"
```

## Check a specific index (replace "properties" with your index name)

```sh
curl -X GET "http://localhost:9200/properties?pretty"
```

## Count in Elasticsearch

```sh
curl -X GET "http://[your-elasticsearch-host]:9200/properties/_count?pretty"
```

## Count in PostgreSQL (run in Supabase SQL Editor)

SELECT COUNT(\*) FROM properties;

## Search by location (using geo query)

```sh
curl -X GET "http://[your-elasticsearch-host]:9200/properties/_search?pretty" -H 'Content-Type: application/json' -d'
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

## Search by full text

```sh
curl -X GET "http://[your-elasticsearch-host]:9200/properties/_search?pretty" -H 'Content-Type: application/json' -d'
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
