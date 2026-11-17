-- =====================================================================
-- Zenvique System — 05_owner_history.sql
-- History log for the Owner Dashboard:
--  * every Settings change (targets, commission, item lists…) with before/after
--  * every reorder-level change and new stock item with before/after
-- (Sales edits, approvals, stock moves/counts and role changes were already logged.)
-- Paste into Supabase > SQL Editor and click Run. Safe to run more than once.
-- =====================================================================

-- 1. Settings changes
create or replace function public.log_settings_change() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform public.write_log('settings change', 'settings', new.key, null,
      jsonb_build_object('setting', new.key, 'before', null, 'after', new.value));
  elsif new.value is distinct from old.value then
    perform public.write_log('settings change', 'settings', new.key, null,
      jsonb_build_object('setting', new.key, 'before', old.value, 'after', new.value));
  end if;
  return new;
end $$;

drop trigger if exists settings_log_change on public.settings;
create trigger settings_log_change
  after insert or update on public.settings
  for each row execute function public.log_settings_change();

-- 2. Reorder level changed by hand (quantity changes are logged by counts / transfers / sales)
create or replace function public.log_stock_change() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.reorder_level is distinct from old.reorder_level then
    perform public.write_log('reorder level change', 'stock', new.id::text, new.location,
      jsonb_build_object('product', new.product,
                         'before', jsonb_build_object('reorder_level', old.reorder_level),
                         'after',  jsonb_build_object('reorder_level', new.reorder_level)));
  end if;
  return new;
end $$;

drop trigger if exists stock_log_change on public.stock;
create trigger stock_log_change
  after update on public.stock
  for each row execute function public.log_stock_change();

-- 3. Voucher type options for the New Sale form
insert into public.settings (key, value)
values ('voucher_types', '["Birthday Voucher", "New Customer Voucher", "Referral Voucher", "Promo Voucher"]')
on conflict (key) do nothing;

-- Done. You should see "Success. No rows returned".
