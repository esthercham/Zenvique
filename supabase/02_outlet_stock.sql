-- =====================================================================
-- Zenvique System — 02_outlet_stock.sql
-- Moves the SAMPLE stock from the old sample outlets (Bangsar, Puchong,
-- Mont Kiara) to the real outlets. HQ stock is not touched.
-- Paste into Supabase > SQL Editor and click Run. Safe to run more than once.
-- =====================================================================

-- 1. Remove sample stock at the old sample outlets
delete from public.stock
 where location in ('Bangsar', 'Puchong', 'Mont Kiara');

-- 2. Sample stock for the real outlets (does not overwrite existing rows)
insert into public.stock (location, product, quantity, reorder_level) values
  ('Petaling Jaya',    'Serum 30ml',      15, 5),
  ('Petaling Jaya',    'Sunscreen SPF50',  4, 5),   -- low on purpose (for testing alerts)
  ('Petaling Jaya',    'Cleanser 150ml',  12, 5),
  ('Damansara Uptown', 'Serum 30ml',      10, 5),
  ('Damansara Uptown', 'Sunscreen SPF50', 18, 5),
  ('Damansara Uptown', 'Cleanser 150ml',   5, 5),   -- at reorder level = low
  ('Setia Taipan',     'Serum 30ml',      20, 5),
  ('Setia Taipan',     'Sunscreen SPF50', 14, 5),
  ('Setia Taipan',     'Cleanser 150ml',   9, 5),
  ('Eco Ardence',      'Serum 30ml',      12, 5),
  ('Eco Ardence',      'Sunscreen SPF50', 10, 5),
  ('Eco Ardence',      'Cleanser 150ml',   3, 5)    -- low on purpose
on conflict (location, product) do nothing;

-- Done. You should see "Success. No rows returned".
