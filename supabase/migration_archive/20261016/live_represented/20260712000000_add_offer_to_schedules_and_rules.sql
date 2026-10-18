-- Migration: Add offer details to scheduled topups and carrier rules

ALTER TABLE public.scheduled_topups 
ADD COLUMN IF NOT EXISTS offer_id character varying,
ADD COLUMN IF NOT EXISTS offer_value bigint;

ALTER TABLE public.carrier_rules 
ADD COLUMN IF NOT EXISTS offer_id character varying,
ADD COLUMN IF NOT EXISTS offer_value bigint;
