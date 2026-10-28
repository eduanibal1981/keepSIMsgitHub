'use strict';
// Exact duration totals come from the private verified-price contract. There is
// deliberately no price multiplication or embedded marketing discount schedule.
function dailyIntent(job) {
 const s=job.catalogue_snapshot,days=s?.period_count;
 const daily=s?.catalogue_details?.data_type>=2||['daily_throttled','daily_cutoff','daily_unlimited'].includes(s?.catalogue_details?.plan_type);
 if(!daily)return null;
 if(!Number.isInteger(days)||days<1||days>365||!s.daily_price_id||!s.daily_source_facts)
  throw Object.assign(Error('Invalid daily intent'),{code:'ESIM_INVALID_INTENT'});
 return {days,facts:s.daily_source_facts};
}
function validateDailyPackage(pkg,job) {
 const intent=dailyIntent(job);if(!intent)return false;
 const f=intent.facts,expectedType=Number(f.data_type)||({daily_throttled:2,daily_cutoff:3,daily_unlimited:4})[f.plan_type];
 return !!pkg&&pkg.packageCode===job.bundle_name&&pkg.currencyCode==='USD'&&pkg.enabled!==false&&
  (pkg.status==null||['ACTIVE','NORMAL','ENABLED'].includes(pkg.status))&&pkg.dataType===expectedType&&
  pkg.durationUnit==='DAY'&&Number(pkg.volume)===Number(f.allowance_bytes)&&
  pkg.price===Math.round(Number(job.catalogue_snapshot.daily_base_price)*10000)&&
  (pkg.fupPolicy??null)===(f.fup_text??null)&&
  (job.operation_kind!=='daily_extension'||(pkg.supportTopUpType===3&&
    (pkg.slug||pkg.packageCode)===(f.alias||f.package_id)));
}
module.exports={dailyIntent,validateDailyPackage};
