-- =============================================
-- IDENTITY ENGINE v2 — Unified Customer Identity
-- =============================================
-- Fixes:
--   1. Uses profiles.user_id (not profiles.id) for auth.users FK
--   2. Adds instagram_handle to profiles table
--   3. Safe retroactive sync with FK guard

-- 1. Phone Normalization (idempotent)
CREATE OR REPLACE FUNCTION public.normalize_phone(phone text)
RETURNS text AS $$
DECLARE
  norm text;
BEGIN
  IF phone IS NULL THEN RETURN NULL; END IF;
  norm := regexp_replace(phone, '[^0-9]', '', 'g');
  IF norm LIKE '0%' THEN norm := substr(norm, 2); END IF;
  IF length(norm) IN (10, 11) THEN norm := '55' || norm; END IF;
  RETURN norm;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Normalize Instagram handle (strip @, lowercase, trim)
CREATE OR REPLACE FUNCTION public.normalize_instagram(handle text)
RETURNS text AS $$
BEGIN
  IF handle IS NULL OR handle = '' THEN RETURN NULL; END IF;
  RETURN lower(trim(replace(handle, '@', '')));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 2. Add instagram_handle to profiles (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'instagram_handle'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN instagram_handle text;
  END IF;
END $$;

-- 3. Trigger: When a live_customer is created/updated, try to link to CRM and App User
CREATE OR REPLACE FUNCTION public.handle_live_customer_sync()
RETURNS TRIGGER AS $$
DECLARE
    v_auth_user_id uuid;
    v_norm_phone text;
    v_norm_insta text;
    v_crm_id uuid;
BEGIN
    v_norm_phone := public.normalize_phone(NEW.whatsapp);
    v_norm_insta := public.normalize_instagram(NEW.instagram_handle);

    -- == STEP A: Find CRM client if not linked ==
    IF NEW.client_id IS NULL AND v_norm_insta IS NOT NULL THEN
        SELECT id INTO v_crm_id FROM public.customers
        WHERE public.normalize_instagram(instagram_handle) = v_norm_insta
          AND merged_into_customer_id IS NULL
        ORDER BY created_at DESC LIMIT 1;

        IF v_crm_id IS NULL AND v_norm_phone IS NOT NULL THEN
            SELECT id INTO v_crm_id FROM public.customers
            WHERE public.normalize_phone(phone) = v_norm_phone
              AND merged_into_customer_id IS NULL
            ORDER BY created_at DESC LIMIT 1;
        END IF;

        IF v_crm_id IS NOT NULL THEN
            NEW.client_id := v_crm_id;
            IF NEW.nome IS NULL OR NEW.nome = '' THEN
                SELECT name INTO NEW.nome FROM public.customers WHERE id = v_crm_id;
            END IF;
        END IF;
    END IF;

    -- == STEP B: Find App User (profiles → auth.users) ==
    -- Try by Instagram first
    IF v_norm_insta IS NOT NULL THEN
        SELECT user_id INTO v_auth_user_id FROM public.profiles
        WHERE public.normalize_instagram(instagram_handle) = v_norm_insta
        LIMIT 1;
    END IF;

    -- Try by WhatsApp if Instagram didn't match
    IF v_auth_user_id IS NULL AND v_norm_phone IS NOT NULL THEN
        SELECT user_id INTO v_auth_user_id FROM public.profiles
        WHERE public.normalize_phone(whatsapp) = v_norm_phone
        LIMIT 1;
    END IF;

    -- == STEP C: Link carts and orders to the auth user ==
    IF v_auth_user_id IS NOT NULL THEN
        UPDATE public.live_carts SET user_id = v_auth_user_id
        WHERE live_customer_id = NEW.id AND user_id IS NULL;

        -- Also link orders by phone (with FK safety check)
        IF v_norm_phone IS NOT NULL THEN
            UPDATE public.orders SET user_id = v_auth_user_id
            WHERE public.normalize_phone(customer_phone) = v_norm_phone
              AND user_id IS NULL
              AND EXISTS (SELECT 1 FROM auth.users WHERE id = v_auth_user_id);
        END IF;
    END IF;

    -- Also try via CRM customer's user_id
    IF NEW.client_id IS NOT NULL AND v_auth_user_id IS NULL THEN
        SELECT user_id INTO v_auth_user_id FROM public.customers WHERE id = NEW.client_id;
        IF v_auth_user_id IS NOT NULL THEN
            UPDATE public.live_carts SET user_id = v_auth_user_id
            WHERE live_customer_id = NEW.id AND user_id IS NULL;
        END IF;
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Never block a sale due to sync failure
    RAISE WARNING 'handle_live_customer_sync error: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Trigger: When a profile is updated (whatsapp or instagram), retroactively link
CREATE OR REPLACE FUNCTION public.handle_profile_sync()
RETURNS TRIGGER AS $$
DECLARE
    v_norm_phone text;
    v_norm_insta text;
    v_auth_user_id uuid;
BEGIN
    v_auth_user_id := NEW.user_id;
    v_norm_phone := public.normalize_phone(NEW.whatsapp);
    v_norm_insta := public.normalize_instagram(NEW.instagram_handle);

    -- Link live_carts by Instagram
    IF v_norm_insta IS NOT NULL THEN
        UPDATE public.live_carts SET user_id = v_auth_user_id
        WHERE user_id IS NULL AND live_customer_id IN (
            SELECT id FROM public.live_customers
            WHERE public.normalize_instagram(instagram_handle) = v_norm_insta
        );
    END IF;

    -- Link live_carts by WhatsApp
    IF v_norm_phone IS NOT NULL THEN
        UPDATE public.live_carts SET user_id = v_auth_user_id
        WHERE user_id IS NULL AND live_customer_id IN (
            SELECT id FROM public.live_customers
            WHERE public.normalize_phone(whatsapp) = v_norm_phone
        );

        -- Link catalog orders by phone (with FK guard)
        IF EXISTS (SELECT 1 FROM auth.users WHERE id = v_auth_user_id) THEN
            UPDATE public.orders SET user_id = v_auth_user_id
            WHERE user_id IS NULL
              AND public.normalize_phone(customer_phone) = v_norm_phone;
        END IF;
    END IF;

    -- Link CRM customer
    IF v_norm_phone IS NOT NULL THEN
        UPDATE public.customers SET user_id = v_auth_user_id
        WHERE user_id IS NULL AND public.normalize_phone(phone) = v_norm_phone;
    END IF;
    IF v_norm_insta IS NOT NULL THEN
        UPDATE public.customers SET user_id = v_auth_user_id
        WHERE user_id IS NULL AND public.normalize_instagram(instagram_handle) = v_norm_insta;
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_profile_sync error: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Apply Triggers
DROP TRIGGER IF EXISTS tr_live_customer_sync ON public.live_customers;
CREATE TRIGGER tr_live_customer_sync
BEFORE INSERT OR UPDATE OF whatsapp, instagram_handle ON public.live_customers
FOR EACH ROW EXECUTE FUNCTION public.handle_live_customer_sync();

DROP TRIGGER IF EXISTS tr_user_registration_sync ON public.profiles;
DROP TRIGGER IF EXISTS tr_profile_sync ON public.profiles;
CREATE TRIGGER tr_profile_sync
AFTER INSERT OR UPDATE OF whatsapp, instagram_handle ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_profile_sync();

-- 6. SAFE Retroactive Sync (one-time)
DO $$
DECLARE
    v_linked_carts int := 0;
    v_linked_orders int := 0;
    v_linked_customers int := 0;
    v_tmp int := 0;
BEGIN
    -- Link live_carts → auth user via Instagram match
    WITH matches AS (
        SELECT lc.id AS cart_id, p.user_id AS auth_uid
        FROM public.live_carts lc
        JOIN public.live_customers lcust ON lc.live_customer_id = lcust.id
        JOIN public.profiles p ON public.normalize_instagram(p.instagram_handle) = public.normalize_instagram(lcust.instagram_handle)
        WHERE lc.user_id IS NULL
          AND p.instagram_handle IS NOT NULL
          AND lcust.instagram_handle IS NOT NULL
          AND EXISTS (SELECT 1 FROM auth.users WHERE id = p.user_id)
    )
    UPDATE public.live_carts lc SET user_id = m.auth_uid
    FROM matches m WHERE lc.id = m.cart_id;
    GET DIAGNOSTICS v_linked_carts = ROW_COUNT;

    -- Link live_carts → auth user via WhatsApp match
    WITH matches AS (
        SELECT lc.id AS cart_id, p.user_id AS auth_uid
        FROM public.live_carts lc
        JOIN public.live_customers lcust ON lc.live_customer_id = lcust.id
        JOIN public.profiles p ON public.normalize_phone(p.whatsapp) = public.normalize_phone(lcust.whatsapp)
        WHERE lc.user_id IS NULL
          AND p.whatsapp IS NOT NULL
          AND lcust.whatsapp IS NOT NULL
          AND EXISTS (SELECT 1 FROM auth.users WHERE id = p.user_id)
    )
    UPDATE public.live_carts lc SET user_id = m.auth_uid
    FROM matches m WHERE lc.id = m.cart_id;
    GET DIAGNOSTICS v_tmp = ROW_COUNT;
    v_linked_carts := v_linked_carts + v_tmp;

    -- Link orders → auth user via WhatsApp match (FK-safe)
    WITH matches AS (
        SELECT o.id AS order_id, p.user_id AS auth_uid
        FROM public.orders o
        JOIN public.profiles p ON public.normalize_phone(p.whatsapp) = public.normalize_phone(o.customer_phone)
        WHERE o.user_id IS NULL
          AND p.whatsapp IS NOT NULL
          AND o.customer_phone IS NOT NULL
          AND EXISTS (SELECT 1 FROM auth.users WHERE id = p.user_id)
    )
    UPDATE public.orders o SET user_id = m.auth_uid
    FROM matches m WHERE o.id = m.order_id;
    GET DIAGNOSTICS v_linked_orders = ROW_COUNT;

    -- Link live_customers → CRM
    UPDATE public.live_customers lcust
    SET client_id = c.id
    FROM public.customers c
    WHERE lcust.client_id IS NULL
      AND public.normalize_instagram(lcust.instagram_handle) = public.normalize_instagram(c.instagram_handle)
      AND c.merged_into_customer_id IS NULL;
    GET DIAGNOSTICS v_linked_customers = ROW_COUNT;

    RAISE NOTICE 'Sync complete: % carts linked, % orders linked, % customers linked', v_linked_carts, v_linked_orders, v_linked_customers;
END $$;
