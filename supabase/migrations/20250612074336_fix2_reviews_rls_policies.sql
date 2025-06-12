-- supabase/migrations/20250615100000_fix_reviews_rls_policies.sql

BEGIN;

-- Drop existing RLS policies on reviews table to start fresh
DROP POLICY IF EXISTS allow_auth_read ON public.reviews;
DROP POLICY IF EXISTS allow_self_insert ON public.reviews;
DROP POLICY IF EXISTS allow_self_delete ON public.reviews;
DROP POLICY IF EXISTS anyone_can_read ON public.reviews;
DROP POLICY IF EXISTS authenticated_can_insert ON public.reviews;
DROP POLICY IF EXISTS users_can_delete_own ON public.reviews;

-- Create proper RLS policies
-- 1. Anyone can read reviews (even unauthenticated users)
CREATE POLICY "anyone_can_read" ON public.reviews
  FOR SELECT USING (true);

-- 2. Authenticated users can insert reviews (with user_id set to their auth.uid())
CREATE POLICY "authenticated_can_insert" ON public.reviews
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- 3. Users can only delete their own reviews
CREATE POLICY "users_can_delete_own" ON public.reviews
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Create a unique index to prevent duplicate reviews by the same user on the same property
-- This only applies to top-level reviews (where parent_id IS NULL)
DROP INDEX IF EXISTS review_unique_per_user;
CREATE UNIQUE INDEX review_unique_per_user ON public.reviews(property_id, user_id)
WHERE parent_id IS NULL;

COMMIT;
