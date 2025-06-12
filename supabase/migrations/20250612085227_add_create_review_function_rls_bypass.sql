BEGIN;

-- Create a stored procedure to insert reviews
-- This function bypasses RLS and acts as a secure wrapper
CREATE OR REPLACE FUNCTION public.create_review(
  p_user_id UUID,
  p_property_id BIGINT,
  p_rating SMALLINT,
  p_comment TEXT,
  p_parent_id UUID
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER -- This runs with the privileges of the function creator
AS $$
DECLARE
  v_id UUID;
  v_auth_uid UUID;
BEGIN
  -- Get the current authenticated user ID
  v_auth_uid := auth.uid();
  
  -- Perform validation checks
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated to create a review';
  END IF;
  
  IF v_auth_uid != p_user_id THEN
    RAISE EXCEPTION 'Cannot create a review with a different user_id than the authenticated user';
  END IF;
  
  -- Check for duplicate reviews (for top-level reviews only)
  IF p_parent_id IS NULL AND EXISTS (
    SELECT 1 FROM public.reviews 
    WHERE user_id = p_user_id 
    AND property_id = p_property_id 
    AND parent_id IS NULL
  ) THEN
    RAISE EXCEPTION 'User has already reviewed this property' 
      USING ERRCODE = '23505'; -- Use the same code as a unique constraint violation
  END IF;
  
  -- Insert the review
  INSERT INTO public.reviews (
    user_id,
    property_id,
    rating,
    comment,
    parent_id
  ) VALUES (
    p_user_id,
    p_property_id,
    p_rating,
    p_comment,
    p_parent_id
  )
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION public.create_review TO authenticated;

COMMIT;
