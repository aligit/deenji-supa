-- Migration: Add reviews table with support for nested replies (comments) for properties
-- This migration creates a "reviews" table where authenticated users can leave one review per property (with a rating and optional comment),
-- and allows unlimited-depth replies to reviews. It also sets up all necessary constraints, indexes, and RLS policies.

BEGIN;

-- 1) Create the reviews table (with property_id as BIGINT, not UUID)
CREATE TABLE public.reviews (
  id          uuid      PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid      NOT NULL,
  property_id bigint    NOT NULL,
  rating      smallint,          -- 1–5 for top-level reviews; NULL on replies
  comment     text,              -- optional text for review or reply
  parent_id   uuid,              -- if reply, points at another review's id

  -- FKs
  CONSTRAINT reviews_id_property_unique UNIQUE (id, property_id),

  CONSTRAINT reviews_user_fkey
    FOREIGN KEY (user_id)
    REFERENCES auth.users (id)
    ON DELETE CASCADE,

  CONSTRAINT reviews_property_fkey
    FOREIGN KEY (property_id)
    REFERENCES public.properties (id)
    ON DELETE CASCADE,

  CONSTRAINT reviews_parent_fkey
    FOREIGN KEY (parent_id, property_id)
    REFERENCES public.reviews (id, property_id)
    ON DELETE CASCADE,

  -- Checks
  CONSTRAINT rating_required CHECK (
    (parent_id IS NULL AND rating BETWEEN 1 AND 5)
    OR
    (parent_id IS NOT NULL AND rating IS NULL)
  ),
  CONSTRAINT no_self_reply CHECK (
    parent_id IS NULL OR parent_id <> id
  )
);

-- 2) Prevent more than one top-level review per user/property
CREATE UNIQUE INDEX unique_user_property_review
  ON public.reviews(user_id, property_id)
  WHERE parent_id IS NULL;

-- 3) Helpful lookup indexes
CREATE INDEX idx_reviews_property ON public.reviews(property_id);
CREATE INDEX idx_reviews_user     ON public.reviews(user_id);
CREATE INDEX idx_reviews_parent   ON public.reviews(parent_id);

-- 4) Enable RLS
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- 5) RLS Policies

-- anyone authenticated can read
CREATE POLICY allow_auth_read
  ON public.reviews
  FOR SELECT
  TO authenticated
  USING (true);

-- only author can insert their own reviews/replies
CREATE POLICY allow_self_insert
  ON public.reviews
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- only author can delete their own reviews/replies
CREATE POLICY allow_self_delete
  ON public.reviews
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- (no UPDATE policy → no edits allowed)

COMMIT;
