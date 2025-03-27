-- Fix for missing Persian text search configuration
-- This migration modifies the search_vector update function to use 'simple' configuration instead

-- Option 1: Try to create a Persian text search configuration if it doesn't exist
DO $$
BEGIN
  -- Check if 'persian' configuration already exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_ts_config WHERE cfgname = 'persian'
  ) THEN
    -- Create a simple Persian text search configuration based on 'simple'
    BEGIN
      EXECUTE 'CREATE TEXT SEARCH CONFIGURATION persian (COPY = simple)';
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not create persian text search configuration: %', SQLERRM;
        -- Continue with the rest of the migration
    END;
  END IF;
END $$;

-- Option 2: Modify the search vector update function to handle missing configuration
CREATE OR REPLACE FUNCTION update_property_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  -- Try to use Persian configuration if available, fall back to simple if not
  BEGIN
    NEW.search_vector = 
      setweight(to_tsvector('persian', COALESCE(NEW.title, '')), 'A') ||
      setweight(to_tsvector('persian', COALESCE(NEW.description, '')), 'B') ||
      setweight(to_tsvector('persian', COALESCE(NEW.city, '')), 'A') ||
      setweight(to_tsvector('persian', COALESCE(NEW.district, '')), 'A') ||
      setweight(to_tsvector('persian', COALESCE(NEW.address, '')), 'B') ||
      setweight(to_tsvector('persian', COALESCE(NEW.type, '')), 'A') ||
      setweight(to_tsvector('persian', COALESCE(NEW.attributes::text, '')), 'C');
  EXCEPTION
    WHEN undefined_object THEN
      -- Fall back to 'simple' configuration if 'persian' is not available
      NEW.search_vector = 
        setweight(to_tsvector('simple', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.description, '')), 'B') ||
        setweight(to_tsvector('simple', COALESCE(NEW.city, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.district, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.address, '')), 'B') ||
        setweight(to_tsvector('simple', COALESCE(NEW.type, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.attributes::text, '')), 'C');
  END;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add comment to explain the function's purpose and behavior
COMMENT ON FUNCTION update_property_search_vector IS 
'Function to update the search_vector column for properties.
Uses Persian text search configuration if available, falls back to simple if not.
Weights different fields: title/city/district (A), description/address (B), attributes (C).';
