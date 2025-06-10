BEGIN;

-- 1) drop the old user → auth.users FK
ALTER TABLE public.reviews
  DROP CONSTRAINT IF EXISTS reviews_user_fkey;

-- 2) add a new user → profiles FK for direct joins
ALTER TABLE public.reviews
  ADD CONSTRAINT reviews_user_profile_fkey
    FOREIGN KEY (user_id)
    REFERENCES public.profiles(id)
    ON DELETE CASCADE;

COMMIT;
