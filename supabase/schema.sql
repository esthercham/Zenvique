-- =====================================================================
-- Zenvique System — schema.sql  (step 1: the database)
-- Paste this whole file into Supabase > SQL Editor and click Run.
-- Safe to run more than once.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------

create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  full_name   text,
  role        text not null default 'staff' check (role in ('owner','manager','staff')),
  outlet      text,                       -- assigned outlet (managers & staff)
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists public.settings (
  key         text primary key,
  value       jsonb not null,
  updated_at  timestamptz not null default now()
);

create table if not exists public.audit_log (
  id          bigint generated always as identity primary key,
  who         uuid default auth.uid(),
  who_email   text,
  at          timestamptz not null default now(),
  action      text not null,
  table_name  text,
  record_id   text,
  outlet      text,
  details     jsonb
);

-- Business table 1: one row per sale
create table if not exists public.sales (
  id                    uuid primary key default gen_random_uuid(),
  created_at            timestamptz not null default now(),
  created_by            uuid default auth.uid() references public.profiles(id),
  updated_at            timestamptz not null default now(),
  sale_date             date not null default (now() at time zone 'Asia/Kuala_Lumpur')::date,
  outlet                text not null check (trim(outlet) <> ''),
  customer_name         text not null check (trim(customer_name) <> ''),
  phone                 text,
  consultant_id         uuid references public.profiles(id),
  service_staff_id      uuid references public.profiles(id),
  product_seller_id     uuid references public.profiles(id),
  treatment             text,
  product               text,
  product_qty           integer not null default 0 check (product_qty >= 0),
  service               text,
  treatment_amount      numeric(12,2) not null default 0 check (treatment_amount >= 0),
  product_amount        numeric(12,2) not null default 0 check (product_amount >= 0),
  service_amount        numeric(12,2) not null default 0 check (service_amount >= 0),
  discount              numeric(12,2) not null default 0 check (discount >= 0),
  voucher_used          boolean not null default false,
  voucher_code          text,
  referred_by           text,
  lead_source           text,
  campaign              text,
  payment_method        text,
  total_sale            numeric(12,2) not null default 0,      -- worked out automatically
  consultant_commission numeric(12,2) not null default 0,      -- worked out automatically
  service_commission    numeric(12,2) not null default 0,      -- worked out automatically
  seller_commission     numeric(12,2) not null default 0,      -- worked out automatically
  status                text not null default 'OK'
                        check (status in ('OK','Needs review','Pending approval')),
  review_reasons        text[] not null default '{}',
  proposed_change       jsonb,          -- manager's fix waiting for owner approval
  change_reason         text,           -- manager's reason
  owner_note            text,           -- owner's reason when rejecting
  reviewed_by           uuid references public.profiles(id),
  reviewed_at           timestamptz,
  notes                 text
);
create index if not exists sales_date_idx        on public.sales (sale_date);
create index if not exists sales_outlet_date_idx on public.sales (outlet, sale_date);

-- Business table 2: one row per product per location (HQ or an outlet)
create table if not exists public.stock (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  created_by    uuid default auth.uid() references public.profiles(id),
  updated_at    timestamptz not null default now(),
  location      text not null check (trim(location) <> ''),
  product       text not null check (trim(product) <> ''),
  quantity      integer not null default 0 check (quantity >= 0),
  reorder_level integer not null default 0 check (reorder_level >= 0),
  unique (location, product)
);

create table if not exists public.ai_briefs (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  created_by  uuid default auth.uid() references public.profiles(id),
  scope       text not null,              -- outlet name or 'All outlets'
  period      text not null,              -- e.g. 'Nov 2026'
  prompt      text not null,
  brief       text not null,
  checked     boolean not null default false check (checked)  -- "I have checked this"
);


-- ---------------------------------------------------------------------
-- 2. HELPER FUNCTIONS
-- ---------------------------------------------------------------------

-- Role of the logged-in person (only if active). Used in every policy.
create or replace function public.my_role() returns text
language sql stable security definer set search_path = ''
as $$ select p.role from public.profiles p where p.id = auth.uid() and p.active $$;

-- Assigned outlet of the logged-in person (only if active).
create or replace function public.my_outlet() returns text
language sql stable security definer set search_path = ''
as $$ select p.outlet from public.profiles p where p.id = auth.uid() and p.active $$;

-- Write one line to the history log.
create or replace function public.write_log(p_action text, p_table text, p_record text,
                                            p_outlet text, p_details jsonb)
returns void language sql security definer set search_path = ''
as $$
  insert into public.audit_log (who, who_email, action, table_name, record_id, outlet, details)
  values (auth.uid(), (select p.email from public.profiles p where p.id = auth.uid()),
          p_action, p_table, p_record, p_outlet, p_details);
$$;

-- Read one number from settings (null if missing => that rule is switched off).
create or replace function public.setting_num(p_key text, p_field text) returns numeric
language sql stable security definer set search_path = ''
as $$ select nullif(s.value ->> p_field, '')::numeric from public.settings s where s.key = p_key $$;

-- Change stock at one location (never below 0).
create or replace function public.adjust_stock(p_location text, p_product text, p_delta integer)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if coalesce(trim(p_product), '') = '' or coalesce(p_delta, 0) = 0 then return; end if;
  update public.stock
     set quantity = greatest(quantity + p_delta, 0), updated_at = now()
   where location = p_location and product = p_product;
end $$;

revoke execute on function public.write_log(text,text,text,text,jsonb) from public, anon, authenticated;
revoke execute on function public.adjust_stock(text,text,integer)       from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 3. PROFILES: auto-create on sign-up, only owner changes role/outlet/active
-- ---------------------------------------------------------------------

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email,
          coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.protect_profile() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  new.id := old.id;
  new.created_at := old.created_at;
  if new.role   is distinct from old.role
  or new.active is distinct from old.active
  or new.outlet is distinct from old.outlet
  or new.email  is distinct from old.email then
    -- auth.uid() is null when run from the SQL Editor: allowed
    if auth.uid() is not null and coalesce(public.my_role(), '') <> 'owner' then
      raise exception 'Only the owner can change roles, outlets or active status.';
    end if;
    perform public.write_log('role change', 'profiles', new.id::text, new.outlet,
      jsonb_build_object('email', new.email,
                         'old_role', old.role,     'new_role', new.role,
                         'old_outlet', old.outlet, 'new_outlet', new.outlet,
                         'old_active', old.active, 'new_active', new.active));
  end if;
  return new;
end $$;

drop trigger if exists protect_profile on public.profiles;
create trigger protect_profile
  before update on public.profiles
  for each row execute function public.protect_profile();


-- ---------------------------------------------------------------------
-- 4. SALES: totals, commission, review flags, stock, manager approval
-- ---------------------------------------------------------------------

-- The fields people type in (everything except worked-out numbers and status).
create or replace function public.sale_core(s public.sales) returns jsonb
language sql stable set search_path = ''
as $$
  select jsonb_build_object(
    'sale_date', s.sale_date, 'outlet', s.outlet, 'customer_name', s.customer_name,
    'phone', s.phone, 'consultant_id', s.consultant_id, 'service_staff_id', s.service_staff_id,
    'product_seller_id', s.product_seller_id, 'treatment', s.treatment, 'product', s.product,
    'product_qty', s.product_qty, 'service', s.service,
    'treatment_amount', s.treatment_amount, 'product_amount', s.product_amount,
    'service_amount', s.service_amount, 'discount', s.discount,
    'voucher_used', s.voucher_used, 'voucher_code', s.voucher_code,
    'referred_by', s.referred_by, 'lead_source', s.lead_source, 'campaign', s.campaign,
    'payment_method', s.payment_method, 'notes', s.notes)
$$;

create or replace function public.sales_before() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_role         text := public.my_role();
  v_is_staff     boolean := auth.uid() is not null and v_role is distinct from 'owner'
                            and v_role is distinct from 'manager';
  v_core_changed boolean := true;
  v_gross        numeric;
  v_limit        numeric;
  v_have         integer;
  v_old_qty      integer := 0;
  v_reasons      text[] := '{}';
begin
  if tg_op = 'INSERT' then
    new.created_by      := coalesce(auth.uid(), new.created_by);
    new.created_at      := now();
    new.updated_at      := now();
    new.proposed_change := null;
    new.change_reason   := null;
    new.owner_note      := null;
    new.reviewed_by     := null;
    new.reviewed_at     := null;
  else
    new.id         := old.id;
    new.created_by := old.created_by;
    new.created_at := old.created_at;
    new.updated_at := now();
    v_core_changed := public.sale_core(new) is distinct from public.sale_core(old);

    -- Manager: an edit becomes a proposal; the sale keeps its old numbers.
    if v_role = 'manager' then
      if v_core_changed then
        if coalesce(trim(new.change_reason), '') = '' then
          raise exception 'Please write a reason for this change.';
        end if;
        new.proposed_change := public.sale_core(new);
        new := jsonb_populate_record(new, public.sale_core(old));
        new.status := 'Pending approval';
        new.owner_note := null;
      else
        new.status          := old.status;
        new.proposed_change := old.proposed_change;
        new.change_reason   := old.change_reason;
        new.owner_note      := old.owner_note;
      end if;
      new.total_sale            := old.total_sale;
      new.consultant_commission := old.consultant_commission;
      new.service_commission    := old.service_commission;
      new.seller_commission     := old.seller_commission;
      new.review_reasons        := old.review_reasons;
      new.reviewed_by           := old.reviewed_by;
      new.reviewed_at           := old.reviewed_at;
      return new;
    end if;

    -- Staff can't touch status or approval fields.
    if v_is_staff then
      new.status          := old.status;
      new.proposed_change := old.proposed_change;
      new.change_reason   := old.change_reason;
      new.owner_note      := old.owner_note;
      new.reviewed_by     := old.reviewed_by;
      new.reviewed_at     := old.reviewed_at;
    end if;

    -- Nothing typed in changed: keep worked-out numbers (owner may change status).
    if not v_core_changed then
      new.total_sale            := old.total_sale;
      new.consultant_commission := old.consultant_commission;
      new.service_commission    := old.service_commission;
      new.seller_commission     := old.seller_commission;
      new.review_reasons        := old.review_reasons;
      if new.status is distinct from old.status then
        if new.status = 'Pending approval' and new.proposed_change is null then
          raise exception 'Only a manager''s change can be marked as Pending approval.';
        end if;
        new.reviewed_by := auth.uid();
        new.reviewed_at := now();
      end if;
      return new;
    end if;
  end if;

  -- Work out totals and commission
  v_gross := new.treatment_amount + new.product_amount + new.service_amount;
  if new.discount > v_gross then
    raise exception 'The discount can''t be more than the sale amount.';
  end if;
  new.total_sale := round(v_gross - new.discount, 2);
  new.consultant_commission := case when new.consultant_id is null then 0 else
    round(new.treatment_amount * coalesce(public.setting_num('commission','consultant_pct'), 0) / 100, 2) end;
  new.service_commission := case when new.service_staff_id is null then 0 else
    round(new.service_amount * coalesce(public.setting_num('commission','service_staff_pct'), 0) / 100, 2) end;
  new.seller_commission := case when new.product_seller_id is null then 0 else
    round(new.product_amount * coalesce(public.setting_num('commission','product_seller_pct'), 0) / 100, 2) end;

  -- Review flags (numbers come from settings)
  v_limit := public.setting_num('review_rules', 'big_discount_pct');
  if v_limit is not null and v_gross > 0 and new.discount > v_gross * v_limit / 100 then
    v_reasons := v_reasons || 'Big discount'::text;
  end if;
  v_limit := public.setting_num('review_rules', 'large_sale_rm');
  if v_limit is not null and new.total_sale > v_limit then
    v_reasons := v_reasons || 'Large sale'::text;
  end if;
  if coalesce(trim(new.phone), '') = '' or new.consultant_id is null
     or coalesce(trim(new.lead_source), '') = '' then
    v_reasons := v_reasons || 'Missing details'::text;
  end if;
  if coalesce(trim(new.product), '') <> '' and new.product_qty > 0 then
    select st.quantity into v_have from public.stock st
     where st.location = new.outlet and st.product = new.product;
    if tg_op = 'UPDATE' and old.outlet = new.outlet and old.product = new.product then
      v_old_qty := old.product_qty;
    end if;
    if v_have is null or v_have + v_old_qty - new.product_qty < 0 then
      v_reasons := v_reasons || 'Stock doesn''t tally'::text;
    end if;
  end if;

  new.review_reasons := v_reasons;
  if tg_op = 'UPDATE' and new.proposed_change is not null then
    new.status := 'Pending approval';
  else
    new.status := case when cardinality(v_reasons) > 0 then 'Needs review' else 'OK' end;
  end if;
  return new;
end $$;

create or replace function public.sales_after() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform public.adjust_stock(new.outlet, new.product, -new.product_qty);
    perform public.write_log('create', 'sales', new.id::text, new.outlet,
      jsonb_build_object('customer', new.customer_name, 'total', new.total_sale,
                         'status', new.status, 'reasons', new.review_reasons));
    return new;
  elsif tg_op = 'UPDATE' then
    if public.sale_core(new) is distinct from public.sale_core(old) then
      perform public.adjust_stock(old.outlet, old.product, old.product_qty);
      perform public.adjust_stock(new.outlet, new.product, -new.product_qty);
      perform public.write_log('edit', 'sales', new.id::text, new.outlet,
        jsonb_build_object('before', public.sale_core(old), 'after', public.sale_core(new)));
    end if;
    if new.status is distinct from old.status then
      perform public.write_log('status change', 'sales', new.id::text, new.outlet,
        jsonb_build_object('from', old.status, 'to', new.status,
                           'reason', new.change_reason, 'proposed', new.proposed_change));
    end if;
    return new;
  else
    perform public.adjust_stock(old.outlet, old.product, old.product_qty);
    perform public.write_log('delete', 'sales', old.id::text, old.outlet,
      public.sale_core(old) || jsonb_build_object('total', old.total_sale));
    return old;
  end if;
end $$;

drop trigger if exists sales_before on public.sales;
create trigger sales_before
  before insert or update on public.sales
  for each row execute function public.sales_before();

drop trigger if exists sales_after on public.sales;
create trigger sales_after
  after insert or update or delete on public.sales
  for each row execute function public.sales_after();

-- Owner approves a manager's change
create or replace function public.approve_sale_change(p_sale uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare v public.sales;
begin
  if public.my_role() is distinct from 'owner' then
    raise exception 'Only the owner can approve changes.';
  end if;
  select * into v from public.sales where id = p_sale for update;
  if not found or v.proposed_change is null then
    raise exception 'There is no change waiting for approval on this sale.';
  end if;
  perform public.write_log('approve change', 'sales', p_sale::text, v.outlet,
    jsonb_build_object('reason', v.change_reason, 'change', v.proposed_change));
  v := jsonb_populate_record(v, v.proposed_change);
  update public.sales set
    sale_date = v.sale_date, outlet = v.outlet, customer_name = v.customer_name, phone = v.phone,
    consultant_id = v.consultant_id, service_staff_id = v.service_staff_id,
    product_seller_id = v.product_seller_id, treatment = v.treatment, product = v.product,
    product_qty = v.product_qty, service = v.service, treatment_amount = v.treatment_amount,
    product_amount = v.product_amount, service_amount = v.service_amount, discount = v.discount,
    voucher_used = v.voucher_used, voucher_code = v.voucher_code, referred_by = v.referred_by,
    lead_source = v.lead_source, campaign = v.campaign, payment_method = v.payment_method,
    notes = v.notes,
    proposed_change = null, owner_note = null, status = 'OK',
    reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_sale;
end $$;

-- Owner rejects a manager's change (sale keeps its old numbers)
create or replace function public.reject_sale_change(p_sale uuid, p_reason text) returns void
language plpgsql security definer set search_path = ''
as $$
declare v public.sales;
begin
  if public.my_role() is distinct from 'owner' then
    raise exception 'Only the owner can reject changes.';
  end if;
  select * into v from public.sales where id = p_sale for update;
  if not found or v.proposed_change is null then
    raise exception 'There is no change waiting for approval on this sale.';
  end if;
  update public.sales set
    proposed_change = null,
    owner_note = nullif(trim(p_reason), ''),
    status = case when cardinality(review_reasons) > 0 then 'Needs review' else 'OK' end,
    reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_sale;
  perform public.write_log('reject change', 'sales', p_sale::text, v.outlet,
    jsonb_build_object('reason', p_reason, 'change', v.proposed_change));
end $$;

-- Commission lines: staff get only their own share, managers their outlet, owner all.
create or replace function public.commission_lines(p_from date, p_to date)
returns table (sale_id uuid, sale_date date, outlet text, staff_id uuid, staff_name text,
               role_in_sale text, base_amount numeric, commission numeric)
language sql stable security definer set search_path = ''
as $$
  with lines as (
    select s.id, s.sale_date, s.outlet, s.consultant_id as staff_id, 'Consultant' as r,
           s.treatment_amount as b, s.consultant_commission as c from public.sales s
    union all
    select s.id, s.sale_date, s.outlet, s.service_staff_id, 'Service Staff',
           s.service_amount, s.service_commission from public.sales s
    union all
    select s.id, s.sale_date, s.outlet, s.product_seller_id, 'Product Seller',
           s.product_amount, s.seller_commission from public.sales s
  )
  select l.id, l.sale_date, l.outlet, l.staff_id, p.full_name, l.r, l.b, l.c
    from lines l
    left join public.profiles p on p.id = l.staff_id
   where l.staff_id is not null
     and l.sale_date between p_from and p_to
     and (   public.my_role() = 'owner'
          or (public.my_role() = 'manager' and l.outlet = public.my_outlet())
          or (public.my_role() = 'staff'   and l.staff_id = auth.uid()))
   order by l.sale_date, l.outlet;
$$;


-- ---------------------------------------------------------------------
-- 5. STOCK: counts by manager/owner, transfers from HQ by owner
-- ---------------------------------------------------------------------

create or replace function public.record_stock_count(p_stock uuid, p_counted integer) returns void
language plpgsql security definer set search_path = ''
as $$
declare v public.stock;
begin
  select * into v from public.stock where id = p_stock for update;
  if not found then raise exception 'This stock item was not found.'; end if;
  if not (public.my_role() = 'owner'
          or (public.my_role() = 'manager' and v.location = public.my_outlet())) then
    raise exception 'You can only count stock at your own outlet.';
  end if;
  if p_counted is null or p_counted < 0 then
    raise exception 'Please enter a count of 0 or more.';
  end if;
  update public.stock set quantity = p_counted, updated_at = now() where id = p_stock;
  perform public.write_log(
    case when p_counted <> v.quantity then 'stock count mismatch' else 'stock count' end,
    'stock', p_stock::text, v.location,
    jsonb_build_object('product', v.product, 'expected', v.quantity, 'counted', p_counted));
end $$;

create or replace function public.transfer_stock(p_product text, p_to text, p_qty integer) returns void
language plpgsql security definer set search_path = ''
as $$
declare v_hq text := coalesce((select s.value ->> 'name' from public.settings s where s.key = 'hq'), 'HQ');
begin
  if public.my_role() is distinct from 'owner' then
    raise exception 'Only the owner can move stock from HQ.';
  end if;
  if p_qty is null or p_qty <= 0 then raise exception 'Please enter a quantity above 0.'; end if;
  if coalesce(trim(p_to), '') = '' or p_to = v_hq then raise exception 'Please pick an outlet.'; end if;
  update public.stock set quantity = quantity - p_qty, updated_at = now()
   where location = v_hq and product = p_product and quantity >= p_qty;
  if not found then raise exception 'HQ does not have enough of this product.'; end if;
  insert into public.stock (location, product, quantity, reorder_level)
  values (p_to, p_product, p_qty, 0)
  on conflict (location, product)
  do update set quantity = public.stock.quantity + excluded.quantity, updated_at = now();
  perform public.write_log('stock transfer', 'stock', null, p_to,
    jsonb_build_object('product', p_product, 'from', v_hq, 'to', p_to, 'qty', p_qty));
end $$;

-- Log new stock rows and new AI briefs
create or replace function public.log_create() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  perform public.write_log('create', tg_table_name, new.id::text,
    case when tg_table_name = 'stock' then (to_jsonb(new) ->> 'location')
         else (to_jsonb(new) ->> 'scope') end,
    to_jsonb(new) - 'prompt' - 'brief');
  return new;
end $$;

drop trigger if exists stock_log_create on public.stock;
create trigger stock_log_create after insert on public.stock
  for each row execute function public.log_create();

drop trigger if exists ai_briefs_log_create on public.ai_briefs;
create trigger ai_briefs_log_create after insert on public.ai_briefs
  for each row execute function public.log_create();


-- ---------------------------------------------------------------------
-- 6. ROW LEVEL SECURITY (the real protection)
-- ---------------------------------------------------------------------

alter table public.profiles  enable row level security;
alter table public.settings  enable row level security;
alter table public.audit_log enable row level security;
alter table public.sales     enable row level security;
alter table public.stock     enable row level security;
alter table public.ai_briefs enable row level security;

-- profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (public.my_role() = 'owner' or id = auth.uid()
         or (outlet is not null and outlet = public.my_outlet()));
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (public.my_role() = 'owner' or id = auth.uid())
  with check (public.my_role() = 'owner' or id = auth.uid());

-- settings
drop policy if exists settings_select on public.settings;
create policy settings_select on public.settings for select to authenticated
  using (public.my_role() is not null);
drop policy if exists settings_owner on public.settings;
create policy settings_owner on public.settings for all to authenticated
  using (public.my_role() = 'owner') with check (public.my_role() = 'owner');

-- audit_log (read only; written by the system)
drop policy if exists audit_select on public.audit_log;
create policy audit_select on public.audit_log for select to authenticated
  using (public.my_role() = 'owner'
         or (public.my_role() = 'manager' and outlet = public.my_outlet()));

-- sales
drop policy if exists sales_select on public.sales;
create policy sales_select on public.sales for select to authenticated
  using (public.my_role() = 'owner'
         or (public.my_role() = 'manager' and outlet = public.my_outlet())
         or (public.my_role() = 'staff' and auth.uid() in
               (created_by, consultant_id, service_staff_id, product_seller_id)));
drop policy if exists sales_insert on public.sales;
create policy sales_insert on public.sales for insert to authenticated
  with check (public.my_role() = 'owner'
              or (public.my_role() in ('manager','staff') and outlet = public.my_outlet()));
drop policy if exists sales_update on public.sales;
create policy sales_update on public.sales for update to authenticated
  using (public.my_role() = 'owner'
         or (public.my_role() = 'manager' and outlet = public.my_outlet())
         or (public.my_role() = 'staff' and created_by = auth.uid()))
  with check (public.my_role() = 'owner'
              or (public.my_role() = 'manager' and outlet = public.my_outlet())
              or (public.my_role() = 'staff' and created_by = auth.uid()
                  and outlet = public.my_outlet()));
drop policy if exists sales_delete on public.sales;
create policy sales_delete on public.sales for delete to authenticated
  using (public.my_role() = 'owner');

-- stock
drop policy if exists stock_select on public.stock;
create policy stock_select on public.stock for select to authenticated
  using (public.my_role() = 'owner'
         or (public.my_role() = 'manager' and location = public.my_outlet()));
drop policy if exists stock_owner on public.stock;
create policy stock_owner on public.stock for all to authenticated
  using (public.my_role() = 'owner') with check (public.my_role() = 'owner');

-- ai_briefs
drop policy if exists briefs_select on public.ai_briefs;
create policy briefs_select on public.ai_briefs for select to authenticated
  using (public.my_role() = 'owner' or created_by = auth.uid());
drop policy if exists briefs_insert on public.ai_briefs;
create policy briefs_insert on public.ai_briefs for insert to authenticated
  with check (public.my_role() in ('owner','manager') and checked);
drop policy if exists briefs_delete on public.ai_briefs;
create policy briefs_delete on public.ai_briefs for delete to authenticated
  using (public.my_role() = 'owner');


-- ---------------------------------------------------------------------
-- 7. ACCESS: nothing for logged-out visitors; commission columns hidden
--    (commission is read through commission_lines(), so staff only see
--    their own share). Pages must list sales columns, not select('*').
-- ---------------------------------------------------------------------

revoke all on public.profiles, public.settings, public.audit_log,
              public.sales, public.stock, public.ai_briefs from anon;

grant select, update                 on public.profiles  to authenticated;
grant select, insert, update, delete on public.settings  to authenticated;
grant select                         on public.audit_log to authenticated;
grant select, insert, update, delete on public.stock     to authenticated;
grant select, insert, delete         on public.ai_briefs to authenticated;

revoke select on public.sales from authenticated;
grant insert, update, delete on public.sales to authenticated;
grant select (id, created_at, created_by, updated_at, sale_date, outlet, customer_name, phone,
              consultant_id, service_staff_id, product_seller_id, treatment, product,
              product_qty, service, treatment_amount, product_amount, service_amount,
              discount, voucher_used, voucher_code, referred_by, lead_source, campaign,
              payment_method, total_sale, status, review_reasons, proposed_change,
              change_reason, owner_note, reviewed_by, reviewed_at, notes)
  on public.sales to authenticated;

revoke execute on function public.commission_lines(date,date)          from public, anon;
revoke execute on function public.approve_sale_change(uuid)            from public, anon;
revoke execute on function public.reject_sale_change(uuid,text)        from public, anon;
revoke execute on function public.record_stock_count(uuid,integer)     from public, anon;
revoke execute on function public.transfer_stock(text,text,integer)    from public, anon;
grant  execute on function public.commission_lines(date,date)          to authenticated;
grant  execute on function public.approve_sale_change(uuid)            to authenticated;
grant  execute on function public.reject_sale_change(uuid,text)        to authenticated;
grant  execute on function public.record_stock_count(uuid,integer)     to authenticated;
grant  execute on function public.transfer_stock(text,text,integer)    to authenticated;


-- ---------------------------------------------------------------------
-- 8. STARTING SETTINGS + SAMPLE STOCK (sample data only; the owner can
--    change all of these later; re-running does not overwrite changes)
-- ---------------------------------------------------------------------

insert into public.settings (key, value) values
  ('outlets',         '["Petaling Jaya", "Damansara Uptown", "Setia Taipan", "Eco Ardence"]'),
  ('hq',              '{"name": "HQ"}'),
  ('commission',      '{"consultant_pct": 10, "service_staff_pct": 5, "product_seller_pct": 5}'),
  ('review_rules',    '{"big_discount_pct": 30, "large_sale_rm": 5000,
                        "open_days": ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]}'),
  ('catalog',         '{"treatments": [{"name": "Facial Basic",       "price": 200.00},
                                       {"name": "Hydra Facial",       "price": 380.00},
                                       {"name": "Acne Treatment",     "price": 280.00}],
                        "products":   [{"name": "Serum 30ml",         "price": 120.00},
                                       {"name": "Sunscreen SPF50",    "price": 85.00},
                                       {"name": "Cleanser 150ml",     "price": 65.00}],
                        "services":   [{"name": "Eyebrow Shaping",    "price": 50.00},
                                       {"name": "Lash Lift",          "price": 120.00}]}'),
  ('lead_sources',    '["Walk-in", "Instagram", "Facebook", "TikTok", "Google", "Referral", "Voucher Campaign"]'),
  ('payment_methods', '["Cash", "Card", "eWallet", "Bank Transfer"]'),
  ('owner_whatsapp',  '{"number": ""}')
on conflict (key) do nothing;

insert into public.stock (location, product, quantity, reorder_level) values
  ('HQ',               'Serum 30ml',      100, 20),
  ('HQ',               'Sunscreen SPF50', 120, 20),
  ('HQ',               'Cleanser 150ml',   80, 20),
  ('Petaling Jaya',    'Serum 30ml',       15,  5),
  ('Petaling Jaya',    'Sunscreen SPF50',   4,  5),
  ('Petaling Jaya',    'Cleanser 150ml',   12,  5),
  ('Damansara Uptown', 'Serum 30ml',       10,  5),
  ('Damansara Uptown', 'Sunscreen SPF50',  18,  5),
  ('Damansara Uptown', 'Cleanser 150ml',    5,  5),
  ('Setia Taipan',     'Serum 30ml',       20,  5),
  ('Setia Taipan',     'Sunscreen SPF50',  14,  5),
  ('Setia Taipan',     'Cleanser 150ml',    9,  5),
  ('Eco Ardence',      'Serum 30ml',       12,  5),
  ('Eco Ardence',      'Sunscreen SPF50',  10,  5),
  ('Eco Ardence',      'Cleanser 150ml',    3,  5)
on conflict (location, product) do nothing;

-- Done. You should see "Success. No rows returned".
