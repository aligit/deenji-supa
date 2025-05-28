
-- 20250528121334_add_lat_lnt_to_properties.sql

-- 1) add two simple columns
ALTER TABLE public.properties
  ADD COLUMN latitude  DOUBLE PRECISION,
  ADD COLUMN longitude DOUBLE PRECISION;

-- 2) (optional) if you want a PostGIS point as well:
    ALTER TABLE public.properties
      ADD COLUMN geom geometry(Point,4326);
    CREATE INDEX ON public.properties USING GIST(geom);
