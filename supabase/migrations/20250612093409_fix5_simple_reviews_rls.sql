-- supabase/migrations/supabase/migrations/20250612093409_fix5_simple_reviews_rls.sql

BEGIN;

-- Drop existing policies to start fresh
DROP POLICY IF EXISTS "anyone_can_read" ON public.reviews;
DROP POLICY IF EXISTS "authenticated_can_insert" ON public.reviews;
DROP POLICY IF EXISTS "users_can_delete_own" ON public.reviews;

-- 1. Anyone can read reviews
CREATE POLICY "anyone_can_read" ON public.reviews
  FOR SELECT USING (true);

-- 2. Authenticated users can insert reviews
CREATE POLICY "authenticated_can_insert" ON public.reviews
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- 3. Users can only delete their own reviews
CREATE POLICY "users_can_delete_own" ON public.reviews
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Make sure the unique constraint is in place to prevent duplicate reviews
DROP INDEX IF EXISTS review_unique_per_user;
CREATE UNIQUE INDEX review_unique_per_user ON public.reviews(property_id, user_id)
WHERE parent_id IS NULL;

COMMIT;
