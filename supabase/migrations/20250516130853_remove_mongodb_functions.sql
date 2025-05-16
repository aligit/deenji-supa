-- Remove MongoDB-related functions since we're no longer importing from MongoDB

-- Drop the MongoDB import function
DROP FUNCTION IF EXISTS public.import_mongodb_property(
  p_external_id text,
  p_title text,
  p_description text,
  p_price bigint,
  p_location jsonb,
  p_attributes jsonb,
  p_image_urls jsonb,
  p_investment_score integer,
  p_market_trend text,
  p_neighborhood_fit_score numeric,
  p_rent_to_price_ratio numeric,
  p_highlight_flags jsonb,
  p_similar_properties jsonb
);

-- Drop the MongoDB attribute processing function
DROP FUNCTION IF EXISTS public.process_mongodb_property_attributes(
  p_property_id bigint,
  p_attributes jsonb
);

-- Keep the insert_property_direct function as it's used by your crawler
-- Keep all table structures as they're still needed for the application

-- Optional: Add a comment to document this cleanup
COMMENT ON SCHEMA public IS 'MongoDB import functions removed - using direct property insertion only';
