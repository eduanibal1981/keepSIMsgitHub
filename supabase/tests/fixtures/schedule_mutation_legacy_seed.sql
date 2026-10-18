-- Synthetic old configuration, with an extra old yearly-batch occurrence.
INSERT INTO public.scheduled_topups(id,sim_line_id,user_id,amount,currency,frequency_days,next_execution_at,schedule_type,base_cost_usd,app_fee_usd,max_authorized_usd,offer_id,preferred_provider)
 VALUES('90000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',2.1,'USD',30,now()+interval '30 days','refill_mini',2,.1,2.1,'fixed','dtone');
INSERT INTO public.topup_executions(sim_line_id,user_id,scheduled_topup_id,amount,execution_type,execution_time)
 VALUES('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001',2.1,'refill_mini',now()+interval '60 days');
