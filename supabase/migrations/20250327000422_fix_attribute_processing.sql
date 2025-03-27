-- Fix for the COALESCE type mismatch in process_mongodb_property_attributes function
-- Error: COALESCE types text and jsonb cannot be matched

-- Create or replace the function with fixed type handling
CREATE OR REPLACE FUNCTION process_mongodb_property_attributes(
  p_property_id BIGINT,
  p_attributes JSONB
)
RETURNS VOID AS $$
DECLARE
  attr JSONB;
  attr_key TEXT;
  attr_title TEXT;
  attr_value TEXT;
  attr_available BOOLEAN;
  attr_key_id BIGINT;
  attr_data_type TEXT;
  attr_json_value JSONB;
BEGIN
  -- For each attribute in the MongoDB data
  IF p_attributes IS NULL OR jsonb_array_length(p_attributes) = 0 THEN
    RETURN;
  END IF;
  
  FOR attr IN SELECT * FROM jsonb_array_elements(p_attributes) LOOP
    -- Extract the key fields
    attr_key := attr->>'key';
    attr_title := attr->>'title';
    attr_value := attr->>'value';
    attr_available := (attr->>'available')::BOOLEAN;
    
    -- First, store all attributes in the JSONB column
    -- Fix: Handle type conversion properly
    IF attr_value IS NOT NULL THEN
      -- Use the text value, converting to JSON
      attr_json_value := to_jsonb(attr_value);
    ELSIF attr_available IS NOT NULL THEN
      -- Use the boolean value
      attr_json_value := to_jsonb(attr_available);
    ELSE
      -- Default to null if neither is available
      attr_json_value := 'null'::jsonb;
    END IF;
    
    -- Use a key from either attr_key or attr_title, but ensure we have a value
    UPDATE properties
    SET attributes = jsonb_set(
      COALESCE(attributes, '{}'::JSONB),
      ARRAY[COALESCE(attr_key, attr_title)],
      attr_json_value
    )
    WHERE id = p_property_id AND COALESCE(attr_key, attr_title) IS NOT NULL;
    
    -- Then, if it's a known attribute, also store it in the structured table
    IF attr_key IS NOT NULL THEN
      -- Find the attribute key
      SELECT id, data_type INTO attr_key_id, attr_data_type 
      FROM property_attribute_keys 
      WHERE name = attr_key;
      
      -- If the key exists, insert the value
      IF attr_key_id IS NOT NULL THEN
        -- Handle boolean attributes differently (available = true/false)
        IF attr_data_type = 'boolean' THEN
          -- For boolean attributes, check if the title contains "ندارد" (doesn't have)
          INSERT INTO property_attribute_values
            (property_id, attribute_key_id, boolean_value)
          VALUES
            (p_property_id, attr_key_id, 
             CASE 
               WHEN attr_available IS NOT NULL THEN attr_available
               WHEN attr_title LIKE '%ندارد%' THEN FALSE
               ELSE TRUE
             END
            )
          ON CONFLICT (property_id, attribute_key_id) 
          DO UPDATE SET boolean_value = EXCLUDED.boolean_value;
        ELSE
          -- For text attributes
          INSERT INTO property_attribute_values
            (property_id, attribute_key_id, text_value)
          VALUES
            (p_property_id, attr_key_id, 
             CASE 
               WHEN attr_title LIKE '%سرویس بهداشتی%' THEN REPLACE(attr_title, 'سرویس بهداشتی ', '')
               WHEN attr_title LIKE '%سرمایش%' THEN REPLACE(attr_title, 'سرمایش ', '')
               WHEN attr_title LIKE '%گرمایش%' THEN REPLACE(attr_title, 'گرمایش ', '')
               WHEN attr_title LIKE '%آب گرم%' THEN REPLACE(attr_title, 'تأمین‌کننده آب گرم ', '')
               WHEN attr_title LIKE '%کف%' THEN REPLACE(attr_title, 'جنس کف ', '')
               ELSE attr_value
             END
            )
          ON CONFLICT (property_id, attribute_key_id) 
          DO UPDATE SET text_value = EXCLUDED.text_value;
        END IF;
      END IF;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Add comment explaining what was fixed
COMMENT ON FUNCTION process_mongodb_property_attributes IS 
'Function to process MongoDB property attributes and store them in PostgreSQL.
Fixes type mismatch error when handling text and boolean attributes.';
