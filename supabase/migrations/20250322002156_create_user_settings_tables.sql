-- Create user_settings table
CREATE TABLE IF NOT EXISTS user_settings (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    language VARCHAR(10) DEFAULT 'fa',
    email_notifications BOOLEAN DEFAULT TRUE,
    property_alerts BOOLEAN DEFAULT TRUE,
    price_drop_alerts BOOLEAN DEFAULT FALSE,
    dark_mode BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Set up Row Level Security (RLS) for user_settings
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- Create policies for user_settings
CREATE POLICY "Users can view their own settings." ON user_settings
  FOR SELECT USING ((auth.uid()) = id);

CREATE POLICY "Users can insert their own settings." ON user_settings
  FOR INSERT WITH CHECK ((auth.uid()) = id);

CREATE POLICY "Users can update their own settings." ON user_settings
  FOR UPDATE USING ((auth.uid()) = id);

-- Create a trigger to create default settings for new users
CREATE OR REPLACE FUNCTION public.handle_new_user_settings()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.user_settings (id, language, email_notifications, property_alerts)
  VALUES (NEW.id, 'fa', TRUE, TRUE);
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created_settings
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user_settings();
