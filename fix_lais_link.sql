
-- Specific Fix for Lais Torres (laistmelo)
-- This script manually links her records if the automatic engine hasn't caught them yet
-- 1. Robust Phone Normalization
CREATE OR REPLACE FUNCTION public.normalize_phone(phone text)
RETURNS text AS $$
DECLARE
  norm text;
BEGIN
  IF phone IS NULL THEN RETURN NULL; END IF;
  norm := regexp_replace(phone, '[^0-9]', '', 'g');
  -- Remove leading 0 if present (common in some formats)
  IF norm LIKE '0%' THEN norm := substr(norm, 2); END IF;
  -- If it has 12 or 13 digits and starts with 55, keep as is
  -- If it has 10 or 11 digits (no country code), prepend 55
  IF length(norm) IN (10, 11) THEN norm := '55' || norm; END IF;
  RETURN norm;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DO $$
DECLARE
    v_handle text := 'laistmelo';
    -- This is the phone we saw in the screenshot (Lais Torres CRM)
    v_user_phone text := '5562982691262'; 
    v_user_id uuid;
    v_crm_id uuid;
BEGIN
    -- 1. Find the Auth User ID from profiles
    SELECT id INTO v_user_id FROM public.profiles 
    WHERE public.normalize_phone(whatsapp) = public.normalize_phone(v_user_phone)
    LIMIT 1;
    
    -- 2. Find the CRM Client ID
    SELECT id INTO v_crm_id FROM public.customers
    WHERE (instagram_handle ILIKE v_handle OR instagram_handle ILIKE '@' || v_handle)
    AND merged_into_customer_id IS NULL
    LIMIT 1;

    IF v_user_id IS NOT NULL THEN
        -- Update the live_customers records
        UPDATE public.live_customers 
        SET whatsapp = v_user_phone,
            client_id = COALESCE(client_id, v_crm_id)
        WHERE (instagram_handle ILIKE v_handle OR instagram_handle ILIKE '@' || v_handle);
        
        -- Link all carts from these customers to the user
        UPDATE public.live_carts
        SET user_id = v_user_id
        WHERE live_customer_id IN (
            SELECT id FROM public.live_customers 
            WHERE (instagram_handle ILIKE v_handle OR instagram_handle ILIKE '@' || v_handle)
        );
        
        -- Link orders
        UPDATE public.orders
        SET user_id = v_user_id
        WHERE public.normalize_phone(customer_phone) = public.normalize_phone(v_user_phone)
           OR customer_name ILIKE '%Lais%';
        
        RAISE NOTICE 'Links updated successfully for Lais Torres (%). UserID: %', v_handle, v_user_id;
    ELSE
        RAISE NOTICE 'Could not find a profile for phone %', v_user_phone;
    END IF;
END $$;
