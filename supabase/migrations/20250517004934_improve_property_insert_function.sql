
-- Migration: 20250517125000_improve_property_insert_function.sql

-- First drop the existing function with its exact signature
DROP FUNCTION IF EXISTS public.insert_property_direct(
  TEXT, TEXT, TEXT, BIGINT, JSONB, JSONB, JSONB, 
  INTEGER, TEXT, NUMERIC, NUMERIC, JSONB, JSONB, 
  BIGINT, BOOLEAN, BOOLEAN, BOOLEAN
);

-- Then create the new function with additional parameters
CREATE OR REPLACE FUNCTION insert_property_direct(
  p_external_id TEXT,
  p_title TEXT,
  p_description TEXT,
  p_price BIGINT,
  p_location JSONB,
  p_attributes JSONB,
  p_image_urls JSONB,
  p_investment_score INTEGER,
  p_market_trend TEXT,
  p_neighborhood_fit_score NUMERIC,
  p_rent_to_price_ratio NUMERIC,
  p_highlight_flags JSONB,
  p_similar_properties JSONB,
  p_price_per_meter BIGINT,
  p_has_parking BOOLEAN,
  p_has_storage BOOLEAN,
  p_has_balcony BOOLEAN,
  p_bedrooms INTEGER DEFAULT NULL,
  p_bathroom_type TEXT DEFAULT NULL,
  p_heating_system TEXT DEFAULT NULL,
  p_cooling_system TEXT DEFAULT NULL,
  p_floor_material TEXT DEFAULT NULL,
  p_hot_water_system TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
  new_property_id BIGINT;
  image_url TEXT;
  similar_id TEXT;
  idx INTEGER;
  attr JSONB;
  area_value NUMERIC;
  year_built_value INTEGER;
  bedrooms_value INTEGER := p_bedrooms; -- Default to passed parameters
  property_type_value TEXT;
  title_deed_type_value TEXT;
  building_direction_value TEXT;
  renovation_status_value TEXT;
  floor_material_value TEXT := p_floor_material;
  bathroom_type_value TEXT := p_bathroom_type;
  cooling_system_value TEXT := p_cooling_system;
  heating_system_value TEXT := p_heating_system;
  hot_water_system_value TEXT := p_hot_water_system;
  cleaned_value TEXT;
BEGIN
  -- Check if property already exists by external_id
  SELECT id INTO new_property_id FROM properties WHERE external_id = p_external_id;
  
  -- Priority: Use directly passed values first, then extract from attributes as fallback
  -- Extract specific attribute values from the attributes JSONB array if direct values weren't provided
  IF p_attributes IS NOT NULL AND jsonb_array_length(p_attributes) > 0 THEN
    FOR attr IN SELECT * FROM jsonb_array_elements(p_attributes) LOOP
      -- Extract basic attributes
      CASE attr->>'title'
        WHEN 'متراژ' THEN
          cleaned_value := regexp_replace(attr->>'value', '[^\d.]', '', 'g');
          -- Only convert if the cleaned value is not empty
          IF cleaned_value IS NOT NULL AND cleaned_value != '' THEN
            area_value := cleaned_value::NUMERIC;
          END IF;
        WHEN 'ساخت' THEN
          cleaned_value := regexp_replace(attr->>'value', '[^\d]', '', 'g');
          IF cleaned_value IS NOT NULL AND cleaned_value != '' THEN
            year_built_value := cleaned_value::INTEGER;
          END IF;
        WHEN 'اتاق' THEN
          -- Only extract bedrooms if not already provided
          IF bedrooms_value IS NULL THEN
            cleaned_value := regexp_replace(attr->>'value', '[^\d]', '', 'g');
            IF cleaned_value IS NOT NULL AND cleaned_value != '' THEN
              bedrooms_value := cleaned_value::INTEGER;
            END IF;
          END IF;
        WHEN 'نوع ملک' THEN
          property_type_value := attr->>'value';
        WHEN 'سند' THEN
          title_deed_type_value := attr->>'value';
        WHEN 'جهت ساختمان' THEN
          building_direction_value := attr->>'value';
        WHEN 'وضعیت واحد' THEN
          renovation_status_value := attr->>'value';
        ELSE
          -- Skip these if direct values were already provided
          IF bathroom_type_value IS NULL AND attr->>'title' LIKE '%سرویس بهداشتی%' 
             AND attr->>'key' = 'WC' AND (attr->>'available')::boolean = true THEN
            bathroom_type_value := TRIM(REPLACE(attr->>'title', 'سرویس بهداشتی ', ''));
          
          ELSIF heating_system_value IS NULL AND attr->>'title' LIKE '%گرمایش%' 
                AND attr->>'key' = 'SUNNY' AND (attr->>'available')::boolean = true THEN
            heating_system_value := TRIM(REPLACE(attr->>'title', 'گرمایش ', ''));
          
          ELSIF cooling_system_value IS NULL AND attr->>'title' LIKE '%سرمایش%' 
                AND attr->>'key' = 'SNOWFLAKE' AND (attr->>'available')::boolean = true THEN
            cooling_system_value := TRIM(REPLACE(attr->>'title', 'سرمایش ', ''));
          
          ELSIF hot_water_system_value IS NULL AND attr->>'title' LIKE '%تأمین‌کننده آب گرم%' 
                AND attr->>'key' = 'THERMOMETER' AND (attr->>'available')::boolean = true THEN
            hot_water_system_value := TRIM(REPLACE(attr->>'title', 'تأمین‌کننده آب گرم ', ''));
          
          ELSIF floor_material_value IS NULL AND attr->>'title' LIKE '%جنس کف%' 
                AND attr->>'key' = 'TEXTURE' AND (attr->>'available')::boolean = true THEN
            floor_material_value := TRIM(REPLACE(attr->>'title', 'جنس کف ', ''));
          END IF;
      END CASE;
    END LOOP;
  END IF;
  
  IF new_property_id IS NOT NULL THEN
    -- Property already exists, update it
    UPDATE properties
    SET 
      title = p_title,
      description = p_description,
      price = p_price,
      price_per_meter = p_price_per_meter,
      area = area_value,
      year_built = year_built_value,
      bedrooms = bedrooms_value,
      type = property_type_value,
      has_parking = p_has_parking,
      has_storage = p_has_storage,
      has_balcony = p_has_balcony,
      title_deed_type = title_deed_type_value,
      building_direction = building_direction_value,
      renovation_status = renovation_status_value,
      floor_material = floor_material_value,
      bathroom_type = bathroom_type_value,
      cooling_system = cooling_system_value,
      heating_system = heating_system_value,
      hot_water_system = hot_water_system_value,
      location = CASE WHEN p_location IS NOT NULL THEN
        ST_SetSRID(ST_MakePoint(
          (p_location->>'longitude')::FLOAT, 
          (p_location->>'latitude')::FLOAT
        ), 4326)
        ELSE NULL
      END,
      attributes = p_attributes,
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
      price_per_meter,
      area,
      year_built,
      bedrooms,
      type,
      has_parking,
      has_storage,
      has_balcony,
      title_deed_type,
      building_direction,
      renovation_status,
      floor_material,
      bathroom_type,
      cooling_system,
      heating_system,
      hot_water_system,
      location,
      attributes,
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
      p_price_per_meter,
      area_value,
      year_built_value,
      bedrooms_value,
      property_type_value,
      p_has_parking,
      p_has_storage,
      p_has_balcony,
      title_deed_type_value,
      building_direction_value,
      renovation_status_value,
      floor_material_value,
      bathroom_type_value,
      cooling_system_value,
      heating_system_value,
      hot_water_system_value,
      CASE WHEN p_location IS NOT NULL THEN
        ST_SetSRID(ST_MakePoint(
          (p_location->>'longitude')::FLOAT, 
          (p_location->>'latitude')::FLOAT
        ), 4326)
        ELSE NULL
      END,
      p_attributes,
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
$$;

-- Add comment explaining what was improved
COMMENT ON FUNCTION insert_property_direct IS 
'Function to insert properties directly from the crawler.
Improved to accept direct parameters for key fields like bedrooms, bathroom_type, and heating_system.
Better handling of complex attributes with key/available structure.
Uses a priority system: direct parameters first, then fallback to attribute extraction.';
