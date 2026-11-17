-- =====================================================================
-- Zenvique System — 03_commission_rules.sql
-- Real commission rules:
--   * Treatment = personal sales  -> Consultant 1% (after discount)
--   * Product                     -> Product Seller 5% (after discount)
--   * Service = treatment DONE today (session amount, may be RM0 paid)
--       -> Beautician: FULL 5% / FOC 1-3% / SHARE 1-4% of session amount
--       -> optional 2nd beautician with their own rate
--   * Total sale = Treatment + Product - Discount (Service is not money paid)
-- Paste into Supabase > SQL Editor and click Run. Safe to run more than once.
-- =====================================================================


-- 1. New columns on sales -----------------------------------------------
alter table public.sales
  add column if not exists service_rate_type   text,
  add column if not exists service_rate_pct    numeric(5,2),
  add column if not exists service_staff2_id   uuid references public.profiles(id),
  add column if not exists service2_rate_type  text,
  add column if not exists service2_rate_pct   numeric(5,2),
  add column if not exists service2_commission numeric(12,2) not null default 0;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'sales_service_rates_chk') then
    alter table public.sales add constraint sales_service_rates_chk check (
          (service_rate_type  is null or service_rate_type  in ('FULL','FOC','SHARE'))
      and (service2_rate_type is null or service2_rate_type in ('FULL','FOC','SHARE'))
      and (service_rate_pct   is null or service_rate_pct   between 0 and 10)
      and (service2_rate_pct  is null or service2_rate_pct  between 0 and 10));
  end if;
end $$;


-- 2. Settings (only replaces the old sample values; keeps owner changes) --
update public.settings
   set value = '{"consultant_pct": 1, "product_seller_pct": 5}', updated_at = now()
 where key = 'commission'
   and value = '{"consultant_pct": 10, "service_staff_pct": 5, "product_seller_pct": 5}'::jsonb;

update public.settings
   set value = '["Bank Transfer", "Cash", "Card", "E-Wallet", "SPayLater / ShopeePay", "Atomy"]',
       updated_at = now()
 where key = 'payment_methods'
   and value = '["Cash", "Card", "eWallet", "Bank Transfer"]'::jsonb;

insert into public.settings (key, value) values
  ('service_rates', '[{"type": "FULL",  "pct": 5},
                      {"type": "FOC",   "pct": 1}, {"type": "FOC",   "pct": 2}, {"type": "FOC",   "pct": 3},
                      {"type": "SHARE", "pct": 1}, {"type": "SHARE", "pct": 2},
                      {"type": "SHARE", "pct": 3}, {"type": "SHARE", "pct": 4}]')
on conflict (key) do nothing;


-- 3. The fields people type in (now includes beautician rates) ----------
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
    'service2_rate_type', s.service2_rate_type, 'service2_rate_pct', s.service2_rate_pct)
$$;


-- 4. Sales rules: totals, commission, review flags, manager approval -----
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
      new.service2_commission   := old.service2_commission;
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
      new.service2_commission   := old.service2_commission;
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

  -- Paid today = Treatment (personal sales) + Product - Discount
  v_paid := new.treatment_amount + new.product_amount;
  if v_paid = 0 and new.service_amount = 0 then
    raise exception 'Please enter a paid amount or a service done.';
  end if;
  if new.discount > v_paid then
    raise exception 'The discount can''t be more than the paid amount.';
  end if;
  new.total_sale := round(v_paid - new.discount, 2);


  -- Sales commission (after discount)
  -- (multiply first, divide once at the end, so no sen is lost)
  new.consultant_commission := case when new.consultant_id is null or v_paid = 0 then 0 else
    trunc(new.treatment_amount * (v_paid - new.discount)
          * coalesce(public.setting_num('commission','consultant_pct'), 0) / (v_paid * 100), 2) end;
  new.seller_commission := case when new.product_seller_id is null or v_paid = 0 then 0 else
    trunc(new.product_amount * (v_paid - new.discount)
          * coalesce(public.setting_num('commission','product_seller_pct'), 0) / (v_paid * 100), 2) end;

  -- Service commission (per visit, on the session amount)
  if new.service_staff_id is null then
    new.service_rate_type := null; new.service_rate_pct := null;
  elsif new.service_rate_pct is null or new.service_rate_type is null then
    raise exception 'Please pick the beautician''s rate (FULL, FOC or SHARE).';
  end if;
  if new.service_staff2_id is null then
    new.service2_rate_type := null; new.service2_rate_pct := null;
  else
    if new.service_staff_id is null then
      raise exception 'Please pick the 1st beautician before the 2nd.';
    end if;
    if new.service_staff2_id = new.service_staff_id then
      raise exception 'The 2nd beautician must be a different person.';
    end if;
    if new.service2_rate_pct is null or new.service2_rate_type is null then
      raise exception 'Please pick the 2nd beautician''s rate (FULL, FOC or SHARE).';
    end if;
  end if;
  new.service_commission  := case when new.service_staff_id  is null then 0 else
    trunc(new.service_amount * new.service_rate_pct  / 100, 2) end;
  new.service2_commission := case when new.service_staff2_id is null then 0 else
    trunc(new.service_amount * new.service2_rate_pct / 100, 2) end;

  -- Review flags (numbers come from settings)
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
  if new.service_amount > 0 and new.service_staff_id is null then
    v_missing := true;
  end if;
  if v_missing then
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


-- 5. Owner approves a manager's change (now includes beautician fields) -
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
    service_rate_type = v.service_rate_type, service_rate_pct = v.service_rate_pct,
    service_staff2_id = v.service_staff2_id,
    service2_rate_type = v.service2_rate_type, service2_rate_pct = v.service2_rate_pct,
    proposed_change = null, owner_note = null, status = 'OK',
    reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_sale;
end $$;


-- 6. Commission lines (staff: own only; manager: outlet; owner: all) ---
drop function if exists public.commission_lines(date, date);
create function public.commission_lines(p_from date, p_to date)
returns table (sale_id uuid, sale_date date, outlet text, customer_name text,
               staff_id uuid, staff_name text, kind text, item text, rate_label text,
               base_amount numeric, commission numeric)
language sql stable security definer set search_path = ''
as $$
  with s as (
    select x.*, case when x.treatment_amount + x.product_amount > 0
                     then x.total_sale / (x.treatment_amount + x.product_amount) else 0 end as f
      from public.sales x
     where x.sale_date between p_from and p_to
  ),
  lines as (
    select s.id, s.sale_date, s.outlet, s.customer_name, s.consultant_id as staff_id,
           'Treatment sale' as kind, s.treatment as item,
           coalesce(public.setting_num('commission','consultant_pct'), 0)::text || '%' as rate_label,
           round(s.treatment_amount * s.f, 2) as base_amount, s.consultant_commission as commission
      from s where s.treatment_amount > 0
    union all
    select s.id, s.sale_date, s.outlet, s.customer_name, s.product_seller_id,
           'Product sale', s.product,
           coalesce(public.setting_num('commission','product_seller_pct'), 0)::text || '%',
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
          or (public.my_role() = 'manager' and l.outlet = public.my_outlet())
          or (public.my_role() = 'staff'   and l.staff_id = auth.uid()))
   order by l.sale_date, l.outlet;
$$;

revoke execute on function public.commission_lines(date,date) from public, anon;
grant  execute on function public.commission_lines(date,date) to authenticated;


-- 7. Who can read the new columns (the 2nd beautician's commission stays hidden)
grant select (service_rate_type, service_rate_pct, service_staff2_id,
              service2_rate_type, service2_rate_pct)
  on public.sales to authenticated;

-- Staff named as 2nd beautician can also see that sale
drop policy if exists sales_select on public.sales;
create policy sales_select on public.sales for select to authenticated
  using (public.my_role() = 'owner'
         or (public.my_role() = 'manager' and outlet = public.my_outlet())
         or (public.my_role() = 'staff' and auth.uid() in
               (created_by, consultant_id, service_staff_id, service_staff2_id, product_seller_id)));

-- Done. You should see "Success. No rows returned".
