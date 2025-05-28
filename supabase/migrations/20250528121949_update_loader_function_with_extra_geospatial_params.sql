
-- 20250528121949_update_loader_function_with_extra_geospatial_params.sql
BEGIN;

-- 1) Drop the *old* 25-arg version (area + year_built only)
DROP FUNCTION IF EXISTS public.insert_property_direct(
  TEXT, TEXT, TEXT, BIGINT,
  JSONB, JSONB, JSONB,
  INTEGER, TEXT, NUMERIC, NUMERIC,
  JSONB, JSONB,
  BIGINT, BOOLEAN, BOOLEAN, BOOLEAN,
  INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT,
  NUMERIC, INTEGER
);

-- 2) Create the new 27-arg version (adds longitude & latitude)
CREATE OR REPLACE FUNCTION public.insert_property_direct(
  p_external_id           TEXT,
  p_title                 TEXT,
  p_description           TEXT,
  p_price                 BIGINT,
  p_location              JSONB,
  p_attributes            JSONB,
  p_image_urls            JSONB,
  p_investment_score      INTEGER,
  p_market_trend          TEXT,
  p_neighborhood_fit_score NUMERIC,
  p_rent_to_price_ratio   NUMERIC,
  p_highlight_flags       JSONB,
  p_similar_properties    JSONB,
  p_price_per_meter       BIGINT,
  p_has_parking           BOOLEAN,
  p_has_storage           BOOLEAN,
  p_has_balcony           BOOLEAN,
  p_bedrooms              INTEGER DEFAULT NULL,
  p_bathroom_type         TEXT    DEFAULT NULL,
  p_heating_system        TEXT    DEFAULT NULL,
  p_cooling_system        TEXT    DEFAULT NULL,
  p_floor_material        TEXT    DEFAULT NULL,
  p_hot_water_system      TEXT    DEFAULT NULL,
  p_area                  NUMERIC DEFAULT NULL,
  p_year_built            INTEGER DEFAULT NULL,
  p_longitude             DOUBLE PRECISION DEFAULT NULL,
  p_latitude              DOUBLE PRECISION DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
  new_property_id BIGINT;
BEGIN
  -- … your existing upsert logic goes here …
  -- be sure in both your UPDATE … SET and INSERT … VALUES you do:
  --     longitude = p_longitude,
  --     latitude  = p_latitude,
  --     location  = CASE
  --                   WHEN p_longitude IS NOT NULL AND p_latitude IS NOT NULL
  --                   THEN ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)
  --                   ELSE NULL
  --                 END,
  --
  -- and at the end RETURN new_property_id;
  RETURN new_property_id;
END;
$$;

COMMIT;
