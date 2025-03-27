-- Fix for the set-returning function error in import_mongodb_property
-- The problem occurs because jsonb_array_elements can't be used in WHERE clauses
-- This migration rewrites the function to use proper filtering approach

CREATE OR REPLACE FUNCTION import_mongodb_property(
  p_external_id TEXT,                -- MongoDB ID
  p_title TEXT,                      -- Property title
  p_description TEXT,                -- Property description
  p_price BIGINT,                    -- Price in IRR
  p_location JSONB,                  -- {latitude: X, longitude: Y}
  p_attributes JSONB,                -- MongoDB attributes array
  p_image_urls JSONB,                -- Array of image URLs
  p_investment_score INTEGER,        -- Investment score
  p_market_trend TEXT,               -- Market trend
  p_neighborhood_fit_score NUMERIC,  -- Neighborhood fit score
  p_rent_to_price_ratio NUMERIC,     -- Rent to price ratio
  p_highlight_flags JSONB,           -- Property highlights
  p_similar_properties JSONB         -- Similar property IDs
)
RETURNS BIGINT AS $$
DECLARE
  new_property_id BIGINT;
  image_url TEXT;
  similar_id TEXT;
  idx INTEGER;
  area_value TEXT;
  year_built_value TEXT;
  bedrooms_value TEXT;
  attr JSONB;
BEGIN
  -- Check if property already exists by external_id
  SELECT id INTO new_property_id FROM properties WHERE external_id = p_external_id;
  
  -- Extract specific attribute values properly
  -- This is the fixed approach that doesn't use SRFs in WHERE clauses
  area_value := NULL;
  year_built_value := NULL;
  bedrooms_value := NULL;
  
  -- Iterate over the attributes array to find what we need
  IF p_attributes IS NOT NULL AND jsonb_array_length(p_attributes) > 0 THEN
    FOR attr IN SELECT * FROM jsonb_array_elements(p_attributes) LOOP
      IF attr->>'title' = 'متراژ' THEN
        area_value := attr->>'value';
      ELSIF attr->>'title' = 'ساخت' THEN
        year_built_value := attr->>'value';
      ELSIF attr->>'title' = 'اتاق' THEN
        bedrooms_value := attr->>'value';
      END IF;
    END LOOP;
  END IF;
  
  -- Convert Persian numerals if needed
  area_value := CASE WHEN area_value IS NOT NULL THEN 
    replace(
      replace(
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(
                      replace(
                        replace(area_value, ',', ''),
                        '۰', '0'),
                        '۱', '1'),
                        '۲', '2'),
                        '۳', '3'),
                        '۴', '4'),
                        '۵', '5'),
                        '۶', '6'),
                        '۷', '7'),
                        '۸', '8'),
                        '۹', '9')
    ELSE NULL END;

  year_built_value := CASE WHEN year_built_value IS NOT NULL THEN 
    replace(
      replace(
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(
                      replace(
                        replace(year_built_value, ',', ''),
                        '۰', '0'),
                        '۱', '1'),
                        '۲', '2'),
                        '۳', '3'),
                        '۴', '4'),
                        '۵', '5'),
                        '۶', '6'),
                        '۷', '7'),
                        '۸', '8'),
                        '۹', '9')
    ELSE NULL END;

  bedrooms_value := CASE WHEN bedrooms_value IS NOT NULL THEN 
    replace(
      replace(
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(
                      replace(
                        replace(bedrooms_value, ',', ''),
                        '۰', '0'),
                        '۱', '1'),
                        '۲', '2'),
                        '۳', '3'),
                        '۴', '4'),
                        '۵', '5'),
                        '۶', '6'),
                        '۷', '7'),
                        '۸', '8'),
                        '۹', '9')
    ELSE NULL END;
  
  IF new_property_id IS NOT NULL THEN
    -- Property already exists, update it
    UPDATE properties
    SET 
      title = p_title,
      description = p_description,
      price = p_price,
      location = ST_SetSRID(ST_MakePoint(
        (p_location->>'longitude')::FLOAT, 
        (p_location->>'latitude')::FLOAT
      ), 4326),
      investment_score = p_investment_score,
      market_trend = p_market_trend,
      neighborhood_fit_score = p_neighborhood_fit_score,
      rent_to_price_ratio = p_rent_to_price_ratio,
      highlight_flags = p_highlight_flags,
      updated_at = NOW()
    WHERE id = new_property_id;
  ELSE
    -- Insert new property
    INSERT INTO properties (
      external_id,
      title,
      description,
      price,
      -- Extract common attributes from the attributes array
      area,
      year_built,
      bedrooms,
      -- Set location as Point
      location,
      -- Set analytics data
      investment_score,
      market_trend,
      neighborhood_fit_score,
      rent_to_price_ratio,
      highlight_flags,
      created_at,
      updated_at
    ) VALUES (
      p_external_id,
      p_title,
      p_description,
      p_price,
      CASE WHEN area_value IS NOT NULL THEN area_value::NUMERIC ELSE NULL END,
      CASE WHEN year_built_value IS NOT NULL THEN year_built_value::INTEGER ELSE NULL END,
      CASE WHEN bedrooms_value IS NOT NULL THEN bedrooms_value::INTEGER ELSE NULL END,
      ST_SetSRID(ST_MakePoint(
        (p_location->>'longitude')::FLOAT, 
        (p_location->>'latitude')::FLOAT
      ), 4326),
      p_investment_score,
      p_market_trend,
      p_neighborhood_fit_score,
      p_rent_to_price_ratio,
      p_highlight_flags,
      NOW(),
      NOW()
    )
    RETURNING id INTO new_property_id;
  END IF;
  
  -- Process attributes
  PERFORM process_mongodb_property_attributes(new_property_id, p_attributes);
  
  -- Process images
  -- First delete existing images to avoid duplicates
  DELETE FROM property_images WHERE property_id = new_property_id;
  
  -- Then insert new images
  IF p_image_urls IS NOT NULL AND jsonb_array_length(p_image_urls) > 0 THEN
    FOR idx IN 0..jsonb_array_length(p_image_urls)-1 LOOP
      image_url := p_image_urls->>idx;
      
      INSERT INTO property_images (
        property_id,
        url,
        is_featured,
        sort_order
      ) VALUES (
        new_property_id,
        image_url,
        idx = 0, -- First image is featured
        idx
      );
    END LOOP;
  END IF;
  
  -- Process similar properties
  -- First delete existing similar properties to avoid duplicates
  DELETE FROM property_similar_properties WHERE property_id = new_property_id;
  
  -- Then insert new similar properties
  IF p_similar_properties IS NOT NULL AND jsonb_array_length(p_similar_properties) > 0 THEN
    FOR idx IN 0..jsonb_array_length(p_similar_properties)-1 LOOP
      similar_id := p_similar_properties->>idx;
      
      INSERT INTO property_similar_properties (
        property_id,
        similar_property_external_id,
        similarity_score
      ) VALUES (
        new_property_id,
        similar_id,
        100 - (idx * 10) -- Arbitrary score based on position
      );
    END LOOP;
  END IF;
  
  RETURN new_property_id;
END;
$$ LANGUAGE plpgsql;

-- Comment explaining the issue and fix
COMMENT ON FUNCTION import_mongodb_property IS 
'Function to import properties from MongoDB to PostgreSQL.
Fixed to avoid using set-returning functions (SRFs) in WHERE clauses.
Now uses explicit iteration to extract metadata values from attributes array.';
