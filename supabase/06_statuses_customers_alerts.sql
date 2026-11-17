-- =====================================================================
-- Zenvique System — 06_statuses_customers_alerts.sql
--  * Customers table (client database): birthday, VIP, status, total spend…
--  * Sales: Transaction status, Payment status + balance + due date, customer link
--  * Stock: Stock Issue status
--  * Every manager change (data OR status) waits for owner approval
--  * Colour rules in Settings + one role-based alerts list (my_alerts)
--  * Everything is written to the History log
-- Paste into Supabase > SQL Editor and click Run. Safe to run more than once.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. CUSTOMERS (business table 3)
-- ---------------------------------------------------------------------
create table if not exists public.customers (
  id               uuid primary key default gen_random_uuid(),
  created_at       timestamptz not null default now(),
  created_by       uuid default auth.uid() references public.profiles(id),
  updated_at       timestamptz not null default now(),
  name             text not null check (trim(name) <> ''),
  phone            text,
  phone_key        text generated always as (nullif(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), '')) stored,
  email            text,
  birthday         date,
  home_outlet      text,
  customer_status  text not null default 'New'
                   check (customer_status in ('New', 'Active', 'Follow-up', 'Inactive')),
  is_vip           boolean not null default false,
  lead_source      text,
  referred_by      text,
  notes            text,
  -- worked out automatically from sales
  visits           integer not null default 0,
  total_spend      numeric(12,2) not null default 0,
  first_visit      date,
  last_visit       date,
  -- manager change waiting for owner approval
  proposed_change  jsonb,
  change_reason    text,
  owner_note       text
);
create index if not exists customers_phone_key_idx on public.customers (phone_key);
create index if not exists customers_name_idx on public.customers (lower(name));


-- ---------------------------------------------------------------------
-- 2. NEW COLUMNS
-- ---------------------------------------------------------------------
alter table public.sales
  add column if not exists customer_id        uuid references public.customers(id),
  add column if not exists transaction_status text not null default 'Completed',
  add column if not exists payment_status     text not null default 'Paid',
  add column if not exists balance_due        numeric(12,2) not null default 0,
  add column if not exists due_date           date,
  add column if not exists consultant_pct_used numeric(5,2),
  add column if not exists seller_pct_used     numeric(5,2);
create index if not exists sales_customer_idx on public.sales (customer_id);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'sales_statuses_chk') then
    alter table public.sales add constraint sales_statuses_chk check (
          transaction_status in ('Completed', 'Cancelled', 'Refunded')
      and payment_status in ('Paid', 'Partial', 'Outstanding')
      and balance_due >= 0);
  end if;
end $$;

alter table public.stock
  add column if not exists issue_status          text not null default 'OK',
  add column if not exists issue_note            text,
  add column if not exists proposed_issue_status text,
  add column if not exists proposed_issue_note   text,
  add column if not exists issue_requested_by    uuid references public.profiles(id);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'stock_issue_chk') then
    alter table public.stock add constraint stock_issue_chk check (
          issue_status in ('OK', 'Damaged', 'Expired', 'Missing', 'Recount needed')
      and (proposed_issue_status is null
           or proposed_issue_status in ('OK', 'Damaged', 'Expired', 'Missing', 'Recount needed')));
  end if;
end $$;

-- Staff phone numbers (for WhatsApp follow-up buttons)
alter table public.profiles add column if not exists phone text;


-- ---------------------------------------------------------------------
-- 3. SETTINGS: colour rules (owner can change these in Settings)
-- ---------------------------------------------------------------------
insert into public.settings (key, value) values
  ('colour_rules', '{"critical_stock_pct": 50, "overdue_days": 0, "target_warning_pct": 80,
                     "high_discount_pct": 20, "alert_lookback_days": 90, "changed_sale_days": 7}')
on conflict (key) do nothing;


-- ---------------------------------------------------------------------
-- 4. CUSTOMERS: rules, approval, totals, history
-- ---------------------------------------------------------------------
create or replace function public.customer_core(c public.customers) returns jsonb
language sql stable set search_path = ''
as $$
  select jsonb_build_object(
    'name', c.name, 'phone', c.phone, 'email', c.email, 'birthday', c.birthday,
    'home_outlet', c.home_outlet, 'customer_status', c.customer_status, 'is_vip', c.is_vip,
    'lead_source', c.lead_source, 'referred_by', c.referred_by, 'notes', c.notes)
$$;

create or replace function public.customers_before() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare v_role text := public.my_role();
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.created_at := now(); new.updated_at := now();
    new.proposed_change := null; new.change_reason := null; new.owner_note := null;
    if coalesce(current_setting('zenvique.sys', true), '') <> 'on' then
      new.visits := 0; new.total_spend := 0; new.first_visit := null; new.last_visit := null;
    end if;
    return new;
  end if;

  -- totals refreshed by the system
  if coalesce(current_setting('zenvique.sys', true), '') = 'on' then return new; end if;

  new.id := old.id; new.created_by := old.created_by; new.created_at := old.created_at;
  new.updated_at := now();
  new.visits := old.visits; new.total_spend := old.total_spend;
  new.first_visit := old.first_visit; new.last_visit := old.last_visit;

  if v_role = 'manager' then
    if public.customer_core(new) is distinct from public.customer_core(old) then
      if coalesce(trim(new.change_reason), '') = '' then
        raise exception 'Please write a reason for this change.';
      end if;
      new.proposed_change := public.customer_core(new);
      new := jsonb_populate_record(new, public.customer_core(old));
      new.owner_note := null;
    else
      new.proposed_change := old.proposed_change;
      new.change_reason := old.change_reason;
      new.owner_note := old.owner_note;
    end if;
  elsif auth.uid() is not null and v_role is distinct from 'owner' then
    raise exception 'Only managers and the owner can change customer records.';
  end if;
  return new;
end $$;

drop trigger if exists customers_before on public.customers;
create trigger customers_before before insert or update on public.customers
  for each row execute function public.customers_before();

create or replace function public.customers_after() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform public.write_log('create', 'customers', new.id::text, new.home_outlet,
      jsonb_build_object('customer', new.name, 'phone', new.phone));
  elsif coalesce(current_setting('zenvique.sys', true), '') <> 'on' then
    if public.customer_core(new) is distinct from public.customer_core(old) then
      perform public.write_log('edit', 'customers', new.id::text, new.home_outlet,
        jsonb_build_object('before', public.customer_core(old), 'after', public.customer_core(new)));
    end if;
    if new.proposed_change is distinct from old.proposed_change and new.proposed_change is not null then
      perform public.write_log('change requested', 'customers', new.id::text, new.home_outlet,
        jsonb_build_object('reason', new.change_reason,
                           'before', public.customer_core(old), 'after', new.proposed_change));
    end if;
  end if;
  return new;
end $$;

drop trigger if exists customers_after on public.customers;
create trigger customers_after after insert or update on public.customers
  for each row execute function public.customers_after();

-- Recalculate a customer's visits / total spend / first & last visit
create or replace function public.refresh_customer(p_customer uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if p_customer is null then return; end if;
  perform set_config('zenvique.sys', 'on', true);
  update public.customers c set
    visits      = x.n,
    total_spend = x.t,
    first_visit = x.f,
    last_visit  = x.l
  from (select count(*) filter (where s.transaction_status = 'Completed') as n,
               coalesce(sum(s.total_sale) filter (where s.transaction_status = 'Completed'), 0) as t,
               min(s.sale_date) as f, max(s.sale_date) as l
          from public.sales s where s.customer_id = p_customer) x
  where c.id = p_customer;
  perform set_config('zenvique.sys', 'off', true);
end $$;
revoke execute on function public.refresh_customer(uuid) from public, anon, authenticated;

-- Owner approves / rejects a manager's customer change
create or replace function public.approve_customer_change(p_customer uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare v public.customers;
begin
  if public.my_role() is distinct from 'owner' then raise exception 'Only the owner can approve changes.'; end if;
  select * into v from public.customers where id = p_customer for update;
  if not found or v.proposed_change is null then
    raise exception 'There is no change waiting for approval on this customer.';
  end if;
  perform public.write_log('approve change', 'customers', p_customer::text, v.home_outlet,
    jsonb_build_object('reason', v.change_reason, 'before', public.customer_core(v), 'after', v.proposed_change));
  v := jsonb_populate_record(v, v.proposed_change);
  update public.customers set
    name = v.name, phone = v.phone, email = v.email, birthday = v.birthday, home_outlet = v.home_outlet,
    customer_status = v.customer_status, is_vip = v.is_vip, lead_source = v.lead_source,
    referred_by = v.referred_by, notes = v.notes,
    proposed_change = null, owner_note = null
  where id = p_customer;
end $$;

create or replace function public.reject_customer_change(p_customer uuid, p_reason text) returns void
language plpgsql security definer set search_path = ''
as $$
declare v public.customers;
begin
  if public.my_role() is distinct from 'owner' then raise exception 'Only the owner can reject changes.'; end if;
  select * into v from public.customers where id = p_customer for update;
  if not found or v.proposed_change is null then
    raise exception 'There is no change waiting for approval on this customer.';
  end if;
  update public.customers set proposed_change = null, owner_note = nullif(trim(p_reason), '') where id = p_customer;
  perform public.write_log('reject change', 'customers', p_customer::text, v.home_outlet,
    jsonb_build_object('reason', p_reason, 'change', v.proposed_change));
end $$;

-- Who may see a customer (used by the customers policy)
create or replace function public.can_see_customer(p_customer uuid, p_home text, p_created_by uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select case public.my_role()
    when 'owner' then true
    when 'manager' then p_home = public.my_outlet()
      or exists (select 1 from public.sales s where s.customer_id = p_customer and s.outlet = public.my_outlet())
    when 'staff' then p_created_by = auth.uid()
      or exists (select 1 from public.sales s where s.customer_id = p_customer
                  and auth.uid() in (s.created_by, s.consultant_id, s.product_seller_id,
                                     s.service_staff_id, s.service_staff2_id))
    else false end
$$;

alter table public.customers enable row level security;
drop policy if exists customers_select on public.customers;
create policy customers_select on public.customers for select to authenticated
  using (public.can_see_customer(id, home_outlet, created_by));
drop policy if exists customers_insert on public.customers;
create policy customers_insert on public.customers for insert to authenticated
  with check (public.my_role() is not null);
drop policy if exists customers_update on public.customers;
create policy customers_update on public.customers for update to authenticated
  using (public.my_role() = 'owner'
         or (public.my_role() = 'manager' and public.can_see_customer(id, home_outlet, created_by)))
  with check (public.my_role() in ('owner', 'manager'));
drop policy if exists customers_delete on public.customers;
create policy customers_delete on public.customers for delete to authenticated
  using (public.my_role() = 'owner');

revoke all on public.customers from anon;
grant select, insert, update, delete on public.customers to authenticated;


-- ---------------------------------------------------------------------
-- 5. SALES: typed-in fields now include statuses, payment and customer
-- ---------------------------------------------------------------------
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
    'payment_method', s.payment_method, 'notes', s.notes,
    'service_rate_type', s.service_rate_type, 'service_rate_pct', s.service_rate_pct,
    'service_staff2_id', s.service_staff2_id,
    'service2_rate_type', s.service2_rate_type, 'service2_rate_pct', s.service2_rate_pct,
    'customer_id', s.customer_id, 'transaction_status', s.transaction_status,
    'payment_status', s.payment_status, 'balance_due', s.balance_due, 'due_date', s.due_date)
$$;

-- Stock a sale takes out (cancelled / refunded sales give it back)
create or replace function public.sale_stock_qty(s public.sales) returns integer
language sql immutable set search_path = ''
as $$ select case when s.transaction_status = 'Completed' then coalesce(s.product_qty, 0) else 0 end $$;

create or replace function public.sales_before() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_role         text := public.my_role();
  v_is_staff     boolean := auth.uid() is not null and v_role is distinct from 'owner'
                            and v_role is distinct from 'manager';
  v_core_changed boolean := true;
  v_paid         numeric;
  v_limit        numeric;
  v_have         integer;
  v_old_qty      integer := 0;
  v_missing      boolean := false;
  v_reasons      text[] := '{}';
  v_key          text;
begin
  -- system linking existing sales to customers: change nothing else
  if tg_op = 'UPDATE' and coalesce(current_setting('zenvique.sys', true), '') = 'on' then
    return new;
  end if;
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

    -- Manager: ANY change (data or status) becomes a proposal for the owner.
    if v_role = 'manager' then
      if v_core_changed
         or (new.status is distinct from old.status and new.status = 'OK' and old.status = 'Needs review') then
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
      new.service2_commission   := old.service2_commission;
      new.seller_commission     := old.seller_commission;
      new.consultant_pct_used   := old.consultant_pct_used;
      new.seller_pct_used       := old.seller_pct_used;
      new.review_reasons        := old.review_reasons;
      new.reviewed_by           := old.reviewed_by;
      new.reviewed_at           := old.reviewed_at;
      return new;
    end if;

    -- Staff can't touch review or approval fields.
    if v_is_staff then
      new.status          := old.status;
      new.proposed_change := old.proposed_change;
      new.change_reason   := old.change_reason;
      new.owner_note      := old.owner_note;
      new.reviewed_by     := old.reviewed_by;
      new.reviewed_at     := old.reviewed_at;
    end if;

    -- Nothing typed in changed: keep worked-out numbers (owner may change review status).
    if not v_core_changed then
      new.total_sale            := old.total_sale;
      new.consultant_commission := old.consultant_commission;
      new.service_commission    := old.service_commission;
      new.service2_commission   := old.service2_commission;
      new.seller_commission     := old.seller_commission;
      new.consultant_pct_used   := old.consultant_pct_used;
      new.seller_pct_used       := old.seller_pct_used;
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

  -- Link to a customer (find by phone, else by name at this outlet, else create)
  if new.customer_id is null and coalesce(trim(new.customer_name), '') <> '' then
    v_key := nullif(regexp_replace(coalesce(new.phone, ''), '\D', '', 'g'), '');
    if v_key is not null then
      select c.id into new.customer_id from public.customers c where c.phone_key = v_key
       order by c.created_at limit 1;
    else
      select c.id into new.customer_id from public.customers c
       where c.phone_key is null and lower(trim(c.name)) = lower(trim(new.customer_name))
         and c.home_outlet is not distinct from new.outlet
       order by c.created_at limit 1;
    end if;
    if new.customer_id is null then
      insert into public.customers (name, phone, home_outlet, lead_source, referred_by, created_by)
      values (trim(new.customer_name), nullif(trim(new.phone), ''), new.outlet,
              new.lead_source, new.referred_by, coalesce(auth.uid(), new.created_by))
      returning id into new.customer_id;
    end if;
  end if;

  -- Payment status rules
  if new.payment_status = 'Paid' then
    new.balance_due := 0; new.due_date := null;
  else
    if coalesce(new.balance_due, 0) <= 0 then
      raise exception 'Please enter the balance still owed.';
    end if;
    if new.due_date is null then
      raise exception 'Please enter the due date for the balance.';
    end if;
  end if;

  -- Paid today = Treatment (personal sales) + Product - Discount
  v_paid := new.treatment_amount + new.product_amount;
  if v_paid = 0 and new.service_amount = 0 then
    raise exception 'Please enter a paid amount or a service done.';
  end if;
  if new.discount > v_paid then
    raise exception 'The discount can''t be more than the paid amount.';
  end if;
  new.total_sale := round(v_paid - new.discount, 2);

  -- Commission (rates used are stored, so later rule changes don't rewrite history)
  if tg_op = 'INSERT' or new.consultant_pct_used is null then
    new.consultant_pct_used := coalesce(public.setting_num('commission','consultant_pct'), 0);
  end if;
  if tg_op = 'INSERT' or new.seller_pct_used is null then
    new.seller_pct_used := coalesce(public.setting_num('commission','product_seller_pct'), 0);
  end if;
  if tg_op = 'UPDATE' then   -- an edit uses today's rules
    new.consultant_pct_used := coalesce(public.setting_num('commission','consultant_pct'), 0);
    new.seller_pct_used     := coalesce(public.setting_num('commission','product_seller_pct'), 0);
  end if;

  if new.service_staff_id is null then
    new.service_rate_type := null; new.service_rate_pct := null;
  elsif new.service_rate_pct is null or new.service_rate_type is null then
    raise exception 'Please pick the beautician''s rate (FULL, FOC or SHARE).';
  end if;
  if new.service_staff2_id is null then
    new.service2_rate_type := null; new.service2_rate_pct := null;
  else
    if new.service_staff_id is null then raise exception 'Please pick the 1st beautician before the 2nd.'; end if;
    if new.service_staff2_id = new.service_staff_id then raise exception 'The 2nd beautician must be a different person.'; end if;
    if new.service2_rate_pct is null or new.service2_rate_type is null then
      raise exception 'Please pick the 2nd beautician''s rate (FULL, FOC or SHARE).';
    end if;
  end if;

  if new.transaction_status = 'Completed' then
    new.consultant_commission := case when new.consultant_id is null or v_paid = 0 then 0 else
      trunc(new.treatment_amount * (v_paid - new.discount) * new.consultant_pct_used / (v_paid * 100), 2) end;
    new.seller_commission := case when new.product_seller_id is null or v_paid = 0 then 0 else
      trunc(new.product_amount * (v_paid - new.discount) * new.seller_pct_used / (v_paid * 100), 2) end;
    new.service_commission  := case when new.service_staff_id  is null then 0 else
      trunc(new.service_amount * new.service_rate_pct  / 100, 2) end;
    new.service2_commission := case when new.service_staff2_id is null then 0 else
      trunc(new.service_amount * new.service2_rate_pct / 100, 2) end;
  else  -- Cancelled / Refunded: no commission
    new.consultant_commission := 0; new.seller_commission := 0;
    new.service_commission := 0; new.service2_commission := 0;
  end if;

  -- Review flags (numbers come from settings)
  if new.transaction_status = 'Completed' then
    v_limit := public.setting_num('review_rules', 'big_discount_pct');
    if v_limit is not null and v_paid > 0 and new.discount > v_paid * v_limit / 100 then
      v_reasons := v_reasons || 'Big discount'::text;
    end if;
    v_limit := public.setting_num('review_rules', 'large_sale_rm');
    if v_limit is not null and new.total_sale > v_limit then
      v_reasons := v_reasons || 'Large sale'::text;
    end if;
    if v_paid > 0 and (coalesce(trim(new.phone), '') = '' or new.consultant_id is null
                       or coalesce(trim(new.lead_source), '') = '') then
      v_missing := true;
    end if;
    if new.service_amount > 0 and new.service_staff_id is null then v_missing := true; end if;
    if v_missing then v_reasons := v_reasons || 'Missing details'::text; end if;
    if coalesce(trim(new.product), '') <> '' and new.product_qty > 0 then
      select st.quantity into v_have from public.stock st
       where st.location = new.outlet and st.product = new.product;
      if tg_op = 'UPDATE' and old.outlet = new.outlet and old.product = new.product then
        v_old_qty := public.sale_stock_qty(old);
      end if;
      if v_have is null or v_have + v_old_qty - new.product_qty < 0 then
        v_reasons := v_reasons || 'Stock doesn''t tally'::text;
      end if;
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
  if tg_op = 'UPDATE' and coalesce(current_setting('zenvique.sys', true), '') = 'on' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    perform public.adjust_stock(new.outlet, new.product, -public.sale_stock_qty(new));
    perform public.refresh_customer(new.customer_id);
    perform public.write_log('create', 'sales', new.id::text, new.outlet,
      jsonb_build_object('customer', new.customer_name, 'total', new.total_sale,
                         'status', new.status, 'reasons', new.review_reasons));
    return new;
  elsif tg_op = 'UPDATE' then
    if public.sale_core(new) is distinct from public.sale_core(old) then
      perform public.adjust_stock(old.outlet, old.product, public.sale_stock_qty(old));
      perform public.adjust_stock(new.outlet, new.product, -public.sale_stock_qty(new));
      perform public.refresh_customer(old.customer_id);
      if new.customer_id is distinct from old.customer_id then perform public.refresh_customer(new.customer_id); end if;
      perform public.write_log('edit', 'sales', new.id::text, new.outlet,
        jsonb_build_object('before', public.sale_core(old), 'after', public.sale_core(new)));
    end if;
    if new.status is distinct from old.status then
      perform public.write_log('status change', 'sales', new.id::text, new.outlet,
        jsonb_build_object('from', old.status, 'to', new.status,
                           'reason', new.change_reason, 'proposed', new.proposed_change,
                           'before', case when new.proposed_change is not null then public.sale_core(old) end));
    end if;
    return new;
  else
    perform public.adjust_stock(old.outlet, old.product, public.sale_stock_qty(old));
    perform public.refresh_customer(old.customer_id);
    perform public.write_log('delete', 'sales', old.id::text, old.outlet,
      public.sale_core(old) || jsonb_build_object('total', old.total_sale));
    return old;
  end if;
end $$;

-- Owner approves a manager's sale change: applies every proposed field
create or replace function public.approve_sale_change(p_sale uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare v public.sales; v_cols text;
begin
  if public.my_role() is distinct from 'owner' then raise exception 'Only the owner can approve changes.'; end if;
  select * into v from public.sales where id = p_sale for update;
  if not found or v.proposed_change is null then
    raise exception 'There is no change waiting for approval on this sale.';
  end if;
  perform public.write_log('approve change', 'sales', p_sale::text, v.outlet,
    jsonb_build_object('reason', v.change_reason, 'before', public.sale_core(v), 'after', v.proposed_change));
  select string_agg(quote_ident(k), ', ') into v_cols
    from jsonb_object_keys(v.proposed_change) k
   where k in (select column_name from information_schema.columns
                where table_schema = 'public' and table_name = 'sales');
  execute format(
    'update public.sales set (%1$s) = (select %1$s from jsonb_populate_record(null::public.sales, $1)),
            proposed_change = null, owner_note = null, status = %2$L,
            reviewed_by = auth.uid(), reviewed_at = now()
      where id = $2', v_cols, 'OK')
  using v.proposed_change, p_sale;
end $$;

-- Customer search for the New Sale form (respects who can see whom)
create or replace function public.find_customers(p_q text) returns setof public.customers
language sql stable security invoker set search_path = ''
as $$
  select * from public.customers c
   where length(trim(coalesce(p_q, ''))) >= 2
     and (c.name ilike '%' || trim(p_q) || '%'
          or c.phone_key like '%' || nullif(regexp_replace(p_q, '\D', '', 'g'), '') || '%')
   order by c.last_visit desc nulls last, c.name
   limit 20
$$;

-- Link existing sales to customers (runs once; later sales link themselves)
do $$
declare r record; v_id uuid; v_key text;
begin
  for r in select * from public.sales where customer_id is null order by sale_date, created_at loop
    v_key := nullif(regexp_replace(coalesce(r.phone, ''), '\D', '', 'g'), '');
    v_id := null;
    if v_key is not null then
      select id into v_id from public.customers where phone_key = v_key order by created_at limit 1;
    else
      select id into v_id from public.customers
       where phone_key is null and lower(trim(name)) = lower(trim(r.customer_name))
         and home_outlet is not distinct from r.outlet order by created_at limit 1;
    end if;
    if v_id is null then
      insert into public.customers (name, phone, home_outlet, lead_source, referred_by, created_by)
      values (trim(r.customer_name), nullif(trim(r.phone), ''), r.outlet, r.lead_source, r.referred_by, r.created_by)
      returning id into v_id;
    end if;
    perform set_config('zenvique.sys', 'on', true);
    update public.sales set customer_id = v_id where id = r.id;
    perform set_config('zenvique.sys', 'off', true);
    perform public.refresh_customer(v_id);
  end loop;
end $$;

grant select (customer_id, transaction_status, payment_status, balance_due, due_date,
              consultant_pct_used, seller_pct_used)
  on public.sales to authenticated;

-- Commission lines: cancelled / refunded sales don't count
create or replace function public.commission_lines(p_from date, p_to date)
returns table (sale_id uuid, sale_date date, outlet text, customer_name text,
               staff_id uuid, staff_name text, kind text, item text, rate_label text,
               base_amount numeric, commission numeric)
language sql stable security definer set search_path = ''
as $$
  with s as (
    select x.*, case when x.treatment_amount + x.product_amount > 0
                     then x.total_sale / (x.treatment_amount + x.product_amount) else 0 end as f
      from public.sales x
     where x.sale_date between p_from and p_to and x.transaction_status = 'Completed'
  ),
  lines as (
    select s.id, s.sale_date, s.outlet, s.customer_name, s.consultant_id as staff_id,
           'Treatment sale' as kind, s.treatment as item,
           trim(trailing '.' from trim(trailing '0' from coalesce(s.consultant_pct_used,
             public.setting_num('commission','consultant_pct'), 0)::text)) || '%' as rate_label,
           round(s.treatment_amount * s.f, 2) as base_amount, s.consultant_commission as commission
      from s where s.treatment_amount > 0
    union all
    select s.id, s.sale_date, s.outlet, s.customer_name, s.product_seller_id,
           'Product sale', s.product,
           trim(trailing '.' from trim(trailing '0' from coalesce(s.seller_pct_used,
             public.setting_num('commission','product_seller_pct'), 0)::text)) || '%',
           round(s.product_amount * s.f, 2), s.seller_commission
      from s where s.product_amount > 0
    union all
    select s.id, s.sale_date, s.outlet, s.customer_name, s.service_staff_id,
           'Service', s.service,
           s.service_rate_type || ' ' || trim(trailing '.' from trim(trailing '0' from s.service_rate_pct::text)) || '%',
           s.service_amount, s.service_commission
      from s where s.service_amount > 0
    union all
    select s.id, s.sale_date, s.outlet, s.customer_name, s.service_staff2_id,
           'Service', s.service,
           s.service2_rate_type || ' ' || trim(trailing '.' from trim(trailing '0' from s.service2_rate_pct::text)) || '%',
           s.service_amount, s.service2_commission
      from s where s.service_amount > 0
  )
  select l.id, l.sale_date, l.outlet, l.customer_name, l.staff_id, p.full_name,
         l.kind, l.item, l.rate_label, l.base_amount, l.commission
    from lines l
    left join public.profiles p on p.id = l.staff_id
   where l.staff_id is not null
     and (   public.my_role() = 'owner'
          or (public.my_role() in ('manager','staff') and l.staff_id = auth.uid()))
   order by l.sale_date, l.outlet;
$$;


-- ---------------------------------------------------------------------
-- 6. STOCK ISSUE STATUS (manager requests, owner approves)
-- ---------------------------------------------------------------------
create or replace function public.set_stock_issue(p_stock uuid, p_status text, p_note text) returns void
language plpgsql security definer set search_path = ''
as $$
declare v public.stock; v_role text := public.my_role();
begin
  select * into v from public.stock where id = p_stock for update;
  if not found then raise exception 'This stock item was not found.'; end if;
  if p_status not in ('OK', 'Damaged', 'Expired', 'Missing', 'Recount needed') then
    raise exception 'Please pick a valid stock issue status.';
  end if;
  if v_role = 'owner' then
    update public.stock set issue_status = p_status, issue_note = nullif(trim(p_note), ''),
           proposed_issue_status = null, proposed_issue_note = null, issue_requested_by = null,
           updated_at = now()
     where id = p_stock;
    perform public.write_log('stock issue change', 'stock', p_stock::text, v.location,
      jsonb_build_object('product', v.product,
        'before', jsonb_build_object('issue_status', v.issue_status, 'issue_note', v.issue_note),
        'after',  jsonb_build_object('issue_status', p_status, 'issue_note', nullif(trim(p_note), ''))));
  elsif v_role = 'manager' and v.location = public.my_outlet() then
    if coalesce(trim(p_note), '') = '' then raise exception 'Please write a note for this change.'; end if;
    update public.stock set proposed_issue_status = p_status, proposed_issue_note = trim(p_note),
           issue_requested_by = auth.uid(), updated_at = now()
     where id = p_stock;
    perform public.write_log('stock issue requested', 'stock', p_stock::text, v.location,
      jsonb_build_object('product', v.product,
        'before', jsonb_build_object('issue_status', v.issue_status),
        'after',  jsonb_build_object('issue_status', p_status), 'reason', trim(p_note)));
  else
    raise exception 'You can only change stock at your own outlet.';
  end if;
end $$;

create or replace function public.decide_stock_issue(p_stock uuid, p_approve boolean, p_reason text) returns void
language plpgsql security definer set search_path = ''
as $$
declare v public.stock;
begin
  if public.my_role() is distinct from 'owner' then raise exception 'Only the owner can approve changes.'; end if;
  select * into v from public.stock where id = p_stock for update;
  if not found or v.proposed_issue_status is null then
    raise exception 'There is no stock change waiting for approval here.';
  end if;
  if p_approve then
    update public.stock set issue_status = v.proposed_issue_status, issue_note = v.proposed_issue_note,
           proposed_issue_status = null, proposed_issue_note = null, issue_requested_by = null, updated_at = now()
     where id = p_stock;
  else
    update public.stock set proposed_issue_status = null, proposed_issue_note = null,
           issue_requested_by = null, updated_at = now()
     where id = p_stock;
  end if;
  perform public.write_log(case when p_approve then 'approve change' else 'reject change' end,
    'stock', p_stock::text, v.location,
    jsonb_build_object('product', v.product, 'reason', coalesce(p_reason, v.proposed_issue_note),
      'before', jsonb_build_object('issue_status', v.issue_status),
      'after',  jsonb_build_object('issue_status', v.proposed_issue_status)));
end $$;

revoke execute on function public.set_stock_issue(uuid, text, text)        from public, anon;
revoke execute on function public.decide_stock_issue(uuid, boolean, text)  from public, anon;
revoke execute on function public.approve_customer_change(uuid)            from public, anon;
revoke execute on function public.reject_customer_change(uuid, text)       from public, anon;
grant  execute on function public.set_stock_issue(uuid, text, text)        to authenticated;
grant  execute on function public.decide_stock_issue(uuid, boolean, text)  to authenticated;
grant  execute on function public.approve_customer_change(uuid)            to authenticated;
grant  execute on function public.reject_customer_change(uuid, text)       to authenticated;


-- ---------------------------------------------------------------------
-- 7. ALERTS: one list per person, Red = Act now, Amber = Watch
--    Staff: own sales / commission / customers · Manager: own outlet · Owner: all
-- ---------------------------------------------------------------------
create or replace function public.my_alerts()
returns table (level text, kind text, outlet text, record_table text, record_id text,
               title text, detail text, customer_name text, customer_phone text,
               staff_id uuid, staff_name text, staff_phone text)
language plpgsql stable security definer set search_path = ''
as $$
#variable_conflict use_column
declare
  v_role   text := public.my_role();
  v_outlet text := public.my_outlet();
  v_me     uuid := auth.uid();
  v_today  date := (now() at time zone 'Asia/Kuala_Lumpur')::date;
  r        jsonb;
  v_crit   numeric; v_overdue int; v_warn numeric; v_hdisc numeric; v_look int; v_chg int;
begin
  if v_role is null then return; end if;
  select s.value into r from public.settings s where s.key = 'colour_rules';
  v_crit    := nullif(r ->> 'critical_stock_pct', '')::numeric;
  v_overdue := nullif(r ->> 'overdue_days', '')::int;
  v_warn    := nullif(r ->> 'target_warning_pct', '')::numeric;
  v_hdisc   := nullif(r ->> 'high_discount_pct', '')::numeric;
  v_look    := nullif(r ->> 'alert_lookback_days', '')::int;
  v_chg     := nullif(r ->> 'changed_sale_days', '')::int;

  return query
  with s as (
    select x.*, (x.treatment_amount + x.product_amount) as paid
      from public.sales x
     where (v_look is null or x.sale_date >= v_today - v_look)
       and (   v_role = 'owner'
            or (v_role = 'manager' and x.outlet = v_outlet)
            or (v_role = 'staff' and v_me in (x.created_by, x.consultant_id, x.product_seller_id,
                                               x.service_staff_id, x.service_staff2_id)))
  ),
  sa as (
    -- RED: invalid / incomplete record
    select 'red'::text as lvl, 'incomplete'::text as k, s.outlet, s.id, 'Incomplete sale record'::text as t,
           concat_ws(' · ',
             case when s.treatment_amount > 0 and coalesce(trim(s.treatment), '') = '' then 'treatment not named' end,
             case when s.product_amount > 0 and coalesce(trim(s.product), '') = '' then 'product not named' end,
             case when s.service_amount > 0 and coalesce(trim(s.service), '') = '' then 'treatment done not named' end,
             case when s.payment_status <> 'Paid' and (s.balance_due <= 0 or s.due_date is null) then 'balance / due date missing' end
           ) as d, s.customer_name as cn, s.phone as cp, s.created_by as who
      from s
     where s.transaction_status = 'Completed'
       and ((s.treatment_amount > 0 and coalesce(trim(s.treatment), '') = '')
         or (s.product_amount > 0 and coalesce(trim(s.product), '') = '')
         or (s.service_amount > 0 and coalesce(trim(s.service), '') = '')
         or (s.payment_status <> 'Paid' and (s.balance_due <= 0 or s.due_date is null)))
    union all
    -- RED: missing consultant / beautician / product seller
    select 'red', 'missing_staff', s.outlet, s.id, 'Missing staff on sale',
           concat_ws(' · ',
             case when s.treatment_amount > 0 and s.consultant_id is null then 'no Consultant' end,
             case when s.service_amount > 0 and s.service_staff_id is null then 'no Beautician' end,
             case when s.product_amount > 0 and s.product_seller_id is null then 'no Product Seller' end),
           s.customer_name, s.phone, s.created_by
      from s
     where s.transaction_status = 'Completed'
       and ((s.treatment_amount > 0 and s.consultant_id is null)
         or (s.service_amount > 0 and s.service_staff_id is null)
         or (s.product_amount > 0 and s.product_seller_id is null))
    union all
    -- RED: commission doesn't match the rates saved on the sale
    select 'red', 'commission_error', s.outlet, s.id, 'Commission calculation error',
           'Saved commission does not match the rates on this sale', s.customer_name, s.phone, s.created_by
      from s
     where s.transaction_status = 'Completed' and s.consultant_pct_used is not null
       and (   s.consultant_commission <> case when s.consultant_id is null or s.paid = 0 then 0 else
                 trunc(s.treatment_amount * (s.paid - s.discount) * s.consultant_pct_used / (s.paid * 100), 2) end
            or s.seller_commission <> case when s.product_seller_id is null or s.paid = 0 then 0 else
                 trunc(s.product_amount * (s.paid - s.discount) * s.seller_pct_used / (s.paid * 100), 2) end
            or s.service_commission <> case when s.service_staff_id is null then 0 else
                 trunc(s.service_amount * s.service_rate_pct / 100, 2) end
            or s.service2_commission <> case when s.service_staff2_id is null then 0 else
                 trunc(s.service_amount * s.service2_rate_pct / 100, 2) end)
    union all
    -- RED: overdue balance
    select 'red', 'overdue', s.outlet, s.id, 'Overdue payment',
           'Balance ' || to_char(s.balance_due, 'FM999,999,990.00') || ' was due ' || to_char(s.due_date, 'FMDD Mon YYYY'),
           s.customer_name, s.phone, s.consultant_id
      from s
     where s.transaction_status = 'Completed' and s.payment_status <> 'Paid' and s.balance_due > 0
       and v_overdue is not null and s.due_date is not null and s.due_date + v_overdue < v_today
    union all
    -- AMBER: partial / outstanding, not yet overdue
    select 'amber', 'partial', s.outlet, s.id,
           case when s.payment_status = 'Partial' then 'Partial payment' else 'Payment outstanding' end,
           'Balance ' || to_char(s.balance_due, 'FM999,999,990.00') ||
             coalesce(' due ' || to_char(s.due_date, 'FMDD Mon YYYY'), ''),
           s.customer_name, s.phone, s.consultant_id
      from s
     where s.transaction_status = 'Completed' and s.payment_status <> 'Paid' and s.balance_due > 0
       and not (v_overdue is not null and s.due_date is not null and s.due_date + v_overdue < v_today)
    union all
    -- AMBER: needs review / waiting for approval
    select 'amber', 'review', s.outlet, s.id, s.status,
           coalesce(nullif(array_to_string(s.review_reasons, ', '), ''), s.change_reason, ''),
           s.customer_name, s.phone, s.created_by
      from s where s.status in ('Needs review', 'Pending approval')
    union all
    -- AMBER: missing lead source / referral / voucher details
    select 'amber', 'missing_marketing', s.outlet, s.id, 'Missing marketing details',
           concat_ws(' · ',
             case when s.paid > 0 and coalesce(trim(s.lead_source), '') = '' then 'no lead source' end,
             case when lower(coalesce(s.lead_source, '')) like '%referr%' and coalesce(trim(s.referred_by), '') = '' then 'referral name missing' end,
             case when s.voucher_used and coalesce(trim(s.voucher_code), '') = '' then 'voucher type / code missing' end),
           s.customer_name, s.phone, s.created_by
      from s
     where s.transaction_status = 'Completed'
       and ((s.paid > 0 and coalesce(trim(s.lead_source), '') = '')
         or (lower(coalesce(s.lead_source, '')) like '%referr%' and coalesce(trim(s.referred_by), '') = '')
         or (s.voucher_used and coalesce(trim(s.voucher_code), '') = ''))
    union all
    -- AMBER: unusually high discount
    select 'amber', 'high_discount', s.outlet, s.id, 'Unusually high discount',
           'Discount ' || to_char(s.discount, 'FM999,999,990.00') || ' = ' ||
             round(s.discount / nullif(s.paid, 0) * 100, 1)::text || '% of ' || to_char(s.paid, 'FM999,999,990.00'),
           s.customer_name, s.phone, s.created_by
      from s
     where s.transaction_status = 'Completed' and v_hdisc is not null and s.paid > 0
       and s.discount > s.paid * v_hdisc / 100
  ),
  changed as (
    -- AMBER (staff): a sale with my name was changed by someone else (commission may have changed)
    select 'amber'::text as lvl, 'changed'::text as k, s.outlet, s.id, 'Your sale was changed'::text as t,
           'Changed by ' || coalesce(a.who_email, 'the owner') || ' on ' || to_char(a.at at time zone 'Asia/Kuala_Lumpur', 'FMDD Mon YYYY') as d,
           s.customer_name as cn, null::text as cp, null::uuid as who
      from s
      join lateral (select l.who_email, l.at from public.audit_log l
                     where l.record_id = s.id::text and l.table_name = 'sales'
                       and l.action in ('edit', 'approve change') and l.who is distinct from v_me
                       and v_chg is not null and l.at > now() - make_interval(days => v_chg)
                     order by l.at desc limit 1) a on true
     where v_role = 'staff'
  ),
  st as (
    select x.* from public.stock x
     where v_role = 'owner' or (v_role = 'manager' and x.location = v_outlet)
  ),
  sk as (
    -- RED: critical low stock / AMBER: at reorder level
    select case when st.quantity = 0 or (v_crit is not null and st.quantity <= floor(st.reorder_level * v_crit / 100))
                then 'red' else 'amber' end as lvl,
           'stock'::text as k, st.location as outlet, st.id,
           case when st.quantity = 0 or (v_crit is not null and st.quantity <= floor(st.reorder_level * v_crit / 100))
                then 'Critical low stock' else 'Low stock' end as t,
           st.product || ': ' || st.quantity || ' left (reorder at ' || st.reorder_level || ')' as d
      from st where st.reorder_level > 0 and st.quantity <= st.reorder_level
    union all
    select 'amber', 'stock_issue', st.location, st.id,
           case when st.proposed_issue_status is not null then 'Stock change waiting for approval' else 'Stock issue: ' || st.issue_status end,
           st.product || coalesce(' → ' || st.proposed_issue_status, '') || coalesce(' · ' || coalesce(st.proposed_issue_note, st.issue_note), '')
      from st where st.issue_status <> 'OK' or st.proposed_issue_status is not null
  ),
  tg as (
    -- AMBER: branch behind its monthly target (pro-rated to today)
    select o.outlet,
           coalesce(((select s2.value from public.settings s2 where s2.key = 'sales_targets')
                       -> to_char(v_today, 'YYYY-MM') ->> o.outlet)::numeric, 0) as target,
           coalesce((select sum(x.total_sale) from public.sales x
                      where x.outlet = o.outlet and x.transaction_status = 'Completed'
                        and x.sale_date between date_trunc('month', v_today)::date and v_today), 0) as actual
      from (select jsonb_array_elements_text(s3.value) as outlet from public.settings s3 where s3.key = 'outlets') o
     where v_role = 'owner' or (v_role = 'manager' and o.outlet = v_outlet)
  ),
  tga as (
    select 'amber'::text as lvl, 'target'::text as k, tg.outlet, 'Behind sales target'::text as t,
           'Sales ' || to_char(tg.actual, 'FM999,999,990.00') || ' of ' || to_char(tg.target, 'FM999,999,990.00') ||
           ' (' || round(tg.actual / tg.target * 100, 1)::text || '%); expected by today: ' ||
           to_char(tg.target * extract(day from v_today) / extract(day from (date_trunc('month', v_today) + interval '1 month - 1 day')), 'FM999,999,990.00') as d
      from tg
     where v_warn is not null and tg.target > 0
       and tg.actual < tg.target * extract(day from v_today)
                       / extract(day from (date_trunc('month', v_today) + interval '1 month - 1 day')) * v_warn / 100
  ),
  cu as (
    -- AMBER (owner): customer change waiting for approval
    select 'amber'::text as lvl, 'customer_change'::text as k, c.home_outlet as outlet, c.id,
           'Customer change waiting for approval'::text as t, coalesce(c.change_reason, '') as d,
           c.name as cn, c.phone as cp
      from public.customers c
     where v_role = 'owner' and c.proposed_change is not null
  )
  select a.lvl, a.k, a.outlet, 'sales'::text, a.id::text, a.t, a.d, a.cn, a.cp, a.who, p.full_name, p.phone
    from sa a left join public.profiles p on p.id = a.who
  union all
  select c.lvl, c.k, c.outlet, 'sales', c.id::text, c.t, c.d, c.cn, c.cp, null, null, null from changed c
  union all
  select k.lvl, k.k, k.outlet, 'stock', k.id::text, k.t, k.d, null, null, null, null, null from sk k
  union all
  select t.lvl, t.k, t.outlet, 'outlet', t.outlet, t.t, t.d, null, null, null, null, null from tga t
  union all
  select c.lvl, c.k, c.outlet, 'customers', c.id::text, c.t, c.d, c.cn, c.cp, null, null, null from cu c
  order by 1 desc, 3, 6;
end $$;

revoke execute on function public.my_alerts() from public, anon;
grant  execute on function public.my_alerts() to authenticated;

-- Done. You should see "Success. No rows returned".
