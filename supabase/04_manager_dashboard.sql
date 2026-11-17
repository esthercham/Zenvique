-- =====================================================================
-- Zenvique System — 04_manager_dashboard.sql
--  * Managers now see ONLY their own commission (not other staff's).
--  * Adds the monthly sales targets setting (owner sets, everyone reads).
-- Paste into Supabase > SQL Editor and click Run. Safe to run more than once.
-- =====================================================================

-- 1. Commission lines: owner sees all; everyone else sees only their own
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
          or (public.my_role() in ('manager','staff') and l.staff_id = auth.uid()))
   order by l.sale_date, l.outlet;
$$;

-- 2. Monthly sales targets, e.g. {"2026-11": {"Petaling Jaya": 60000}}
insert into public.settings (key, value) values ('sales_targets', '{}')
on conflict (key) do nothing;

-- Done. You should see "Success. No rows returned".
