-- Add columns to existing profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS user_type VARCHAR(20) CHECK (user_type IN ('buyer', 'agent')),
ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE;
