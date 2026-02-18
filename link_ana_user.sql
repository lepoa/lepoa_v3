
-- Tenta vincular o carrinho e o cliente da live ao usuário do app
-- Baseado no telefone ou email (se houver correspondência)

DO $$
DECLARE
    target_phone text := '5562982797213'; -- Telefone do print (Ana Moularzel)
    found_user_id uuid;
BEGIN
    -- 1. Tentar achar o usuário pelo telefone na tabela profiles
    SELECT id INTO found_user_id
    FROM public.profiles
    WHERE phone = target_phone OR whatsapp = target_phone
    LIMIT 1;

    -- Se não achou em profiles, tenta achar em auth.users (caso phone esteja lá)
    IF found_user_id IS NULL THEN
        SELECT id INTO found_user_id
        FROM auth.users
        WHERE phone = target_phone
        LIMIT 1;
    END IF;

    -- Se achou o usuário, faz o vínculo
    IF found_user_id IS NOT NULL THEN
        RAISE NOTICE 'Usuário encontrado: %', found_user_id;

        -- Atualiza o live_customer
        UPDATE public.live_customers
        SET user_id = found_user_id
        WHERE instagram_handle ILIKE '%anamou%' OR whatsapp = target_phone;

        -- Atualiza os carrinhos (live_carts) deste cliente
        UPDATE public.live_carts
        SET user_id = found_user_id
        WHERE live_customer_id IN (
            SELECT id FROM public.live_customers 
            WHERE instagram_handle ILIKE '%anamou%' OR whatsapp = target_phone
        );
        
        RAISE NOTICE 'Vínculo realizado com sucesso!';
    ELSE
        RAISE NOTICE 'Nenhum usuário encontrado com o telefone %', target_phone;
    END IF;
END $$;
