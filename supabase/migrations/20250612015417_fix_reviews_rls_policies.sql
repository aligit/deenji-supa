-- Create a new migration file: supabase/migrations/20250615000000_fix_reviews_rls_policies.sql

BEGIN;

-- Drop existing RLS policies on reviews table
DROP POLICY IF EXISTS allow_self_insert ON public.reviews;
DROP POLICY IF EXISTS allow_auth_read ON public.reviews;
DROP POLICY IF EXISTS allow_self_delete ON public.reviews;

-- Create improved RLS policies

-- Anyone can read reviews
CREATE POLICY "Anyone can read reviews"
  ON public.reviews
  FOR SELECT
  USING (true);

-- Authenticated users can insert reviews
CREATE POLICY "Authenticated users can insert reviews"
  ON public.reviews
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Only the author can delete their own reviews
CREATE POLICY "Users can delete own reviews"
  ON public.reviews
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- No UPDATE policy - reviews cannot be edited

COMMIT;
