-- Function to generate reward coupon
create or replace function generate_reward_coupon()
returns text
language plpgsql
as $$
declare
  chars text[] := '{A,B,C,D,E,F,G,H,J,K,L,M,N,P,Q,R,S,T,U,V,W,X,Y,Z,2,3,4,5,6,7,8,9}';
  result text := '';
  i integer;
begin
  for i in 1..8 loop
    result := result || chars[1 + floor(random() * array_length(chars, 1))::int];
  end loop;
  return 'CLUB-' || result;
end;
$$;

-- Function to award loyalty points (from missions/quiz) and update tier
create or replace function award_loyalty_points(
  p_user_id uuid,
  p_points integer,
  p_description text,
  p_mission_id text default null
)
returns void
language plpgsql
security definer
as $$
declare
  v_loyalty_id uuid;
  v_current_points integer;
  v_new_annual_points integer;
  v_new_tier text;
begin
  -- Get or create loyalty record
  select id, annual_points
  into v_loyalty_id, v_new_annual_points
  from customer_loyalty
  where user_id = p_user_id;

  if v_loyalty_id is null then
    v_new_annual_points := 0;
    insert into customer_loyalty (user_id, current_points, lifetime_points, annual_points, current_tier)
    values (p_user_id, 0, 0, 0, 'poa'::loyalty_tier)
    returning id into v_loyalty_id;
  end if;

  -- Calculate new annual points
  v_new_annual_points := v_new_annual_points + p_points;

  -- Determine new tier
  if v_new_annual_points >= 6000 then
    v_new_tier := 'poa_black';
  elsif v_new_annual_points >= 3000 then
    v_new_tier := 'poa_platinum';
  elsif v_new_annual_points >= 1000 then
    v_new_tier := 'poa_gold';
  else
    v_new_tier := 'poa';
  end if;

  -- Update loyalty record
  update customer_loyalty
  set 
    current_points = current_points + p_points,
    lifetime_points = lifetime_points + p_points,
    annual_points = annual_points + p_points,
    current_tier = v_new_tier::loyalty_tier,
    updated_at = now()
  where id = v_loyalty_id;

  -- Log transaction
  insert into point_transactions (
    user_id,
    type,
    points,
    description,
    mission_id,
    created_at
  ) values (
    p_user_id,
    'mission',
    p_points,
    p_description,
    p_mission_id,
    now()
  );
end;
$$;
