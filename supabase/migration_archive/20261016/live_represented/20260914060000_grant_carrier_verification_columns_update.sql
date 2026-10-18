-- Migration: 20260914060000_grant_carrier_verification_columns_update.sql
-- Description: Grant column-level UPDATE on carrier verification fields to authenticated role.
-- Fixes Defect 1: 'permission denied for table sim_lines' during nickname and client-side updates.

GRANT UPDATE (
  is_carrier_verified,
  carrier_status,
  detected_operator_name,
  carrier_verified_at
) ON public.sim_lines TO authenticated;
