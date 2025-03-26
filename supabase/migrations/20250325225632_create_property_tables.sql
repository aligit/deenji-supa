-- Enable PostGIS for geospatial data
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create the core properties table
CREATE TABLE IF NOT EXISTS properties (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  external_id VARCHAR(50) UNIQUE, -- Original MongoDB ID (e.g., "QZtj1fYF")
  title VARCHAR(255) NOT NULL,
  description TEXT,
  price BIGINT, -- Store in lowest denomination (IRR)
  price_per_meter BIGINT,
  type VARCHAR(50), -- "Apartment", etc.
  bedrooms SMALLINT,
  bathrooms SMALLINT,
  area NUMERIC(10,2), -- in square meters
  year_built SMALLINT,
  
  -- Location data
  location GEOMETRY(POINT, 4326), -- PostgreSQL can store geographic coordinates
  address TEXT,
  city VARCHAR(100),
  district VARCHAR(100),
  
  -- Additional information
  floor_number SMALLINT,
  total_floors SMALLINT,
  units_per_floor SMALLINT,
  
  -- Property features
  has_elevator BOOLEAN DEFAULT FALSE,
  has_parking BOOLEAN DEFAULT FALSE,
  has_storage BOOLEAN DEFAULT FALSE,
  has_balcony BOOLEAN DEFAULT FALSE,
  
  -- Interior details
  floor_material VARCHAR(100), -- "سرامیک", "پارکت چوب", etc. 
  bathroom_type VARCHAR(100),  -- "ایرانی", "ایرانی و فرنگی", etc.
  cooling_system VARCHAR(100),
  heating_system VARCHAR(100),
  hot_water_system VARCHAR(100),
  
  -- Document information
  title_deed_type VARCHAR(100),
  building_direction VARCHAR(50), -- "شمالی", "جنوبی", etc.
  renovation_status VARCHAR(100), -- "بازسازی شده", "بازسازی نشده", etc.
  
  -- Real estate agency data
  agency_name VARCHAR(255),
  agent_name VARCHAR(255),
  agent_id UUID REFERENCES auth.users(id),
  
  -- Analytics data
  investment_score SMALLINT,      -- 0-100 score
  market_trend VARCHAR(50),       -- "Rising", "Stable", "Declining"
  neighborhood_fit_score NUMERIC(3,1),
  rent_to_price_ratio NUMERIC(3,1),
  
  -- Dynamic attributes from MongoDB (key-value pairs)
  attributes JSONB DEFAULT '{}',
  
  -- Flags and highlights
  highlight_flags JSONB,          -- Store as JSON array ["Great View", "Close to Metro"]
  
  -- Search vector for full-text search
  search_vector TSVECTOR,
  
  -- User tracking
  owner_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for properties table
CREATE INDEX IF NOT EXISTS idx_properties_external_id ON properties(external_id);
CREATE INDEX IF NOT EXISTS idx_properties_type ON properties(type);
CREATE INDEX IF NOT EXISTS idx_properties_city ON properties(city);
CREATE INDEX IF NOT EXISTS idx_properties_price ON properties(price);
CREATE INDEX IF NOT EXISTS idx_properties_bedrooms ON properties(bedrooms);
CREATE INDEX IF NOT EXISTS idx_properties_area ON properties(area);
CREATE INDEX IF NOT EXISTS idx_properties_year_built ON properties(year_built);
CREATE INDEX IF NOT EXISTS idx_properties_location ON properties USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_properties_attributes ON properties USING GIN(attributes);
CREATE INDEX IF NOT EXISTS idx_properties_search_vector ON properties USING GIN(search_vector);

-- Create table for property images
CREATE TABLE IF NOT EXISTS property_images (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  property_id BIGINT REFERENCES properties(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  is_featured BOOLEAN DEFAULT FALSE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_property_images_property_id ON property_images(property_id);

-- Create table for property amenities
CREATE TABLE IF NOT EXISTS amenities (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(100) UNIQUE,
  icon VARCHAR(100), -- Optional icon identifier
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Junction table for many-to-many relationship between properties and amenities
CREATE TABLE IF NOT EXISTS property_amenities (
  property_id BIGINT REFERENCES properties(id) ON DELETE CASCADE,
  amenity_id BIGINT REFERENCES amenities(id) ON DELETE CASCADE,
  PRIMARY KEY (property_id, amenity_id)
);

-- Create table for property price history
CREATE TABLE IF NOT EXISTS property_price_history (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  property_id BIGINT REFERENCES properties(id) ON DELETE CASCADE,
  price BIGINT NOT NULL,
  recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_property_price_history_property_id ON property_price_history(property_id);

-- Create table for similar properties
CREATE TABLE IF NOT EXISTS property_similar_properties (
  property_id BIGINT REFERENCES properties(id) ON DELETE CASCADE,
  similar_property_external_id VARCHAR(50),
  similarity_score NUMERIC(5,2),
  PRIMARY KEY (property_id, similar_property_external_id)
);

-- Create tables for structured dynamic attributes
CREATE TABLE IF NOT EXISTS property_attribute_keys (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  display_name VARCHAR(100) NOT NULL,
  data_type VARCHAR(50) NOT NULL CHECK (data_type IN ('text', 'number', 'boolean')),
  is_searchable BOOLEAN DEFAULT FALSE,
  is_filterable BOOLEAN DEFAULT FALSE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS property_attribute_values (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  attribute_key_id BIGINT NOT NULL REFERENCES property_attribute_keys(id),
  text_value TEXT,
  numeric_value NUMERIC,
  boolean_value BOOLEAN,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT property_attribute_unique UNIQUE (property_id, attribute_key_id)
);

-- Create indexes for attribute values
CREATE INDEX IF NOT EXISTS idx_property_attribute_values_property_id ON property_attribute_values(property_id);
CREATE INDEX IF NOT EXISTS idx_property_attribute_values_key_text ON property_attribute_values(attribute_key_id, text_value) WHERE text_value IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_property_attribute_values_key_numeric ON property_attribute_values(attribute_key_id, numeric_value) WHERE numeric_value IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_property_attribute_values_key_boolean ON property_attribute_values(attribute_key_id, boolean_value) WHERE boolean_value IS NOT NULL;

-- Create saved properties table
CREATE TABLE IF NOT EXISTS saved_properties (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT user_property_unique UNIQUE (user_id, property_id)
);

CREATE INDEX IF NOT EXISTS idx_saved_properties_user_id ON saved_properties(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_properties_property_id ON saved_properties(property_id);

-- Function to update the updated_at column automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to keep the updated_at column current
CREATE TRIGGER trg_properties_updated_at
BEFORE UPDATE ON properties
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Function to update the search_vector when relevant fields change
CREATE OR REPLACE FUNCTION update_property_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector = 
    setweight(to_tsvector('persian', COALESCE(NEW.title, '')), 'A') ||
    setweight(to_tsvector('persian', COALESCE(NEW.description, '')), 'B') ||
    setweight(to_tsvector('persian', COALESCE(NEW.city, '')), 'A') ||
    setweight(to_tsvector('persian', COALESCE(NEW.district, '')), 'A') ||
    setweight(to_tsvector('persian', COALESCE(NEW.address, '')), 'B') ||
    setweight(to_tsvector('persian', COALESCE(NEW.type, '')), 'A') ||
    setweight(to_tsvector('persian', COALESCE(NEW.attributes::text, '')), 'C');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_property_search_vector
BEFORE INSERT OR UPDATE OF title, description, city, district, address, type, attributes
ON properties
FOR EACH ROW
EXECUTE FUNCTION update_property_search_vector();

-- Function to handle MongoDB attribute migration
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
    UPDATE properties
    SET attributes = jsonb_set(
      COALESCE(attributes, '{}'::JSONB),
      ARRAY[COALESCE(attr_key, attr_title)],
      to_jsonb(COALESCE(attr_value, to_jsonb(attr_available)))
    )
    WHERE id = p_property_id;
    
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

-- Function to import property from MongoDB
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
  extracted_data JSONB;
  image_url TEXT;
  similar_id TEXT;
  idx INTEGER;
BEGIN
  -- Check if property already exists by external_id
  SELECT id INTO new_property_id FROM properties WHERE external_id = p_external_id;
  
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
    -- Extract data from attributes
    SELECT 
      (jsonb_array_elements(p_attributes)->>'value')::TEXT AS meterage,
      (jsonb_array_elements(p_attributes)->>'value')::TEXT AS year_built,
      (jsonb_array_elements(p_attributes)->>'value')::TEXT AS bedrooms
    FROM 
      jsonb_array_elements(p_attributes)
    WHERE 
      (jsonb_array_elements(p_attributes)->>'title') = 'متراژ' OR
      (jsonb_array_elements(p_attributes)->>'title') = 'ساخت' OR
      (jsonb_array_elements(p_attributes)->>'title') = 'اتاق'
    INTO extracted_data;
    
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
      (SELECT replace(unnest(jsonb_array_elements(p_attributes) ->> 'value'), ',', '')::NUMERIC 
       FROM jsonb_array_elements(p_attributes) 
       WHERE jsonb_array_elements(p_attributes) ->> 'title' = 'متراژ' LIMIT 1),
      (SELECT replace(unnest(jsonb_array_elements(p_attributes) ->> 'value'), ',', '')::INTEGER 
       FROM jsonb_array_elements(p_attributes) 
       WHERE jsonb_array_elements(p_attributes) ->> 'title' = 'ساخت' LIMIT 1),
      (SELECT replace(unnest(jsonb_array_elements(p_attributes) ->> 'value'), ',', '')::INTEGER 
       FROM jsonb_array_elements(p_attributes) 
       WHERE jsonb_array_elements(p_attributes) ->> 'title' = 'اتاق' LIMIT 1),
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

-- Insert common attribute keys found in MongoDB data
INSERT INTO property_attribute_keys 
  (name, display_name, data_type, is_searchable, is_filterable, sort_order)
VALUES
  ('ELEVATOR', 'آسانسور', 'boolean', false, true, 10),
  ('PARKING', 'پارکینگ', 'boolean', false, true, 20),
  ('CABINET', 'انباری', 'boolean', false, true, 30),
  ('BALCONY', 'بالکن', 'boolean', false, true, 40),
  ('WC', 'سرویس بهداشتی', 'text', false, true, 50),
  ('SNOWFLAKE', 'سرمایش', 'text', false, true, 60),
  ('SUNNY', 'گرمایش', 'text', false, true, 70),
  ('THERMOMETER', 'آب گرم', 'text', false, true, 80),
  ('TEXTURE', 'جنس کف', 'text', false, true, 90)
ON CONFLICT (name) DO NOTHING;

-- Create notification function for Elasticsearch sync
CREATE OR REPLACE FUNCTION notify_property_changes()
RETURNS trigger AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    PERFORM pg_notify('property_changes', json_build_object(
      'operation', TG_OP,
      'record_id', OLD.id
    )::text);
    RETURN OLD;
  ELSE
    PERFORM pg_notify('property_changes', json_build_object(
      'operation', TG_OP,
      'record_id', NEW.id
    )::text);
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for Elasticsearch sync
CREATE TRIGGER trg_notify_property_changes
AFTER INSERT OR UPDATE OR DELETE ON properties
FOR EACH ROW EXECUTE FUNCTION notify_property_changes();

-- Set up Row Level Security (RLS)
ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_properties ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Everyone can view properties" ON properties
  FOR SELECT USING (true);

CREATE POLICY "Agents can insert properties" ON properties
  FOR INSERT WITH CHECK (auth.uid() = owner_id OR auth.uid() = agent_id);

CREATE POLICY "Agents can update their own properties" ON properties
  FOR UPDATE USING (auth.uid() = owner_id OR auth.uid() = agent_id);

CREATE POLICY "Agents can delete their own properties" ON properties
  FOR DELETE USING (auth.uid() = owner_id OR auth.uid() = agent_id);

CREATE POLICY "Everyone can view property images" ON property_images
  FOR SELECT USING (true);

CREATE POLICY "Everyone can view property amenities" ON property_amenities
  FOR SELECT USING (true);

CREATE POLICY "Users can view their saved properties" ON saved_properties
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can save properties" ON saved_properties
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their saved properties" ON saved_properties
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their saved properties" ON saved_properties
  FOR DELETE USING (auth.uid() = user_id);
