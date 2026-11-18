-- =====================================================================
-- Zenvique System — 08_language.sql
-- Remembers each person's screen language (EN / 中文) so it follows them
-- to any phone or computer after they log in.
--  * profiles.language: 'en' or 'zh' (empty = not chosen yet)
--  * each person can change their own language; it is not a role change,
--    so it is not blocked by the owner-only rule and not written to History
-- Paste into Supabase > SQL Editor and click Run. Safe to run more than once.
-- =====================================================================

alter table public.profiles
  add column if not exists language text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_language_check') then
    alter table public.profiles
      add constraint profiles_language_check check (language is null or language in ('en', 'zh'));
  end if;
end $$;
