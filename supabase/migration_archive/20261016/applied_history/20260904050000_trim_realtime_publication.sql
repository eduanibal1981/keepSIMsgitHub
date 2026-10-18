-- Migration: 20260904050000_trim_realtime_publication.sql
-- Trims Supabase Realtime publication to strictly user-facing client tables.
-- Drops internal backend/daemon tables (refill_requests, system_configs) that cause
-- heavy WAL decoding overhead in realtime.list_changes.

DO $$
BEGIN
  -- Remove refill_requests from supabase_realtime if present
  IF EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'refill_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.refill_requests;
  END IF;

  -- Ensure system_configs is removed from supabase_realtime if present
  IF EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'system_configs'
  ) THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.system_configs;
  END IF;
END $$;