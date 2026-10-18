import { EndpointError } from "./endpoint-auth.ts";
import { providerSecretClient, requireProviderSecret } from "./provider-secrets.ts";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const phone = /^\+[1-9][0-9]{6,14}$/;
export function money(value: unknown): number {
  if ((typeof value !== "string" && typeof value !== "number") || String(value).trim() === "") throw new EndpointError(502, "Number price unavailable");
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount < 0 || amount > 10000) throw new EndpointError(502, "Number price unavailable");
  return Math.round((amount + Number.EPSILON) * 100) / 100;
}
export class SecondNumbers {
  readonly headers: Record<string,string>;
  readonly url: string;
  readonly key: string;
  constructor(url: string, key: string) {
    this.url=url;
    this.key=key;
    this.headers = { apikey:key, Authorization:`Bearer ${key}`, "Content-Type":"application/json", Prefer:"return=representation" };
  }
  async db(path: string, method = "GET", body?: unknown): Promise<any> {
    const response = await fetch(`${this.url}/rest/v1/${path}`, { method, headers:this.headers,
      body:body === undefined ? undefined : JSON.stringify(body), signal:AbortSignal.timeout(15000) });
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      if (String(error.message).includes("Insufficient available balance")) throw new EndpointError(409,"Insufficient available wallet balance.");
      if (String(error.message).includes("Quote expired")) throw new EndpointError(409,"Your quote expired. Refresh available numbers.");
      if (String(error.message).includes("Number is no longer available")) throw new EndpointError(409,"This number is no longer available. Choose another number.");
      throw new EndpointError(503,"Second Number is temporarily unavailable. Please retry the same request.");
    }
    const text = await response.text();
    return text ? JSON.parse(text) : null;
  }
  rpc(name: string, args: unknown) { return this.db(`rpc/${name}`,"POST",args); }
  async config(name: string): Promise<string> {
    const env = Deno.env.get(name);
    if (env) return env;
    const rows = await this.db(`system_configs?config_key=eq.${encodeURIComponent(name)}&select=config_value`);
    if (!rows[0]?.config_value) throw new EndpointError(503,"Number service configuration is incomplete.");
    return rows[0].config_value;
  }
  async carrier(path: string, method = "GET", body?: unknown): Promise<{ status:number; data:any }> {
    const token = await requireProviderSecret(providerSecretClient(this.url,this.key),"TELNYX_API_KEY");
    const response = await fetch(`https://api.telnyx.com/v2/${path}`, { method,
      headers:{ Authorization:`Bearer ${token}`, "Content-Type":"application/json" },
      body:body === undefined ? undefined : JSON.stringify(body), signal:AbortSignal.timeout(20000) });
    return { status:response.status, data:await response.json().catch(() => ({})) };
  }
  async policies(userId: string) {
    if (!await this.pilotAllowed(userId)) return [];
    return await this.db("second_number_policies?enabled=eq.true&select=country_code,country_name,number_type&order=country_name");
  }
  async pilotAllowed(userId: string): Promise<boolean> {
    const rows = await this.db("second_number_purchase_gate?singleton=eq.true&select=enabled,pilot_user_ids");
    return rows[0]?.enabled === true && rows[0].pilot_user_ids?.includes(userId) === true;
  }
  async validatePilot() {
    const results=[];
    for (const [country,type] of [["US","local"],["GB","mobile"]]) {
      const q=new URLSearchParams({"filter[country_code]":country,"filter[phone_number_type]":type,"filter[features][]":"sms","filter[limit]":"3"});
      const response=await this.carrier(`available_phone_numbers?${q}`);
      const items=Array.isArray(response.data.data)?response.data.data:[];
      results.push({country_code:country,number_type:type,http_status:response.status,sample_count:items.length,
        samples:items.map((item:any)=>({sms:item.features?.some((f:any)=>f.name==="sms")===true,
          voice:item.features?.some((f:any)=>f.name==="voice")===true,cost:item.cost_information||null,
          requirements_met:item.requirements_met??null,best_effort:item.best_effort??null}))});
    }
    return {success:true,probes:results,notice:"Inventory observation only. End-user eligibility, routing and retail terms still require validation."};
  }
  async search(userId: string, input: any) {
    const country = String(input.country_code || "").toUpperCase();
    if (!/^[A-Z]{2}$/.test(country)) throw new EndpointError(400,"Choose a country.");
    if (!await this.pilotAllowed(userId)) return { success:true,numbers:[] };
    const policies = await this.db(`second_number_policies?enabled=eq.true&country_code=eq.${country}&select=*`);
    const result = [];
    if (!policies.length) return { success:true,numbers:[] };
    // Account discounts use the same settled-evidence contract as checkout.
    const tier = await this.rpc("resolve_account_commerce_benefit",{p_user_id:userId});
    if (!["free","standard","premium"].includes(tier)) throw new EndpointError(503,"Number pricing is unavailable.");
    for (const policy of policies) {
      const q = new URLSearchParams({ "filter[country_code]":country,"filter[phone_number_type]":policy.number_type,
        "filter[features][]":"sms","filter[limit]":String(Math.max(1,Math.min(15,Number(input.limit)||15))) });
      // This release sells incoming SMS. Voice activation is a separate, gated release.
      if (input.area_code && /^\d{1,6}$/.test(input.area_code)) q.set("filter[national_destination_code]",input.area_code);
      const response = await this.carrier(`available_phone_numbers?${q}`);
      if (response.status !== 200) throw new EndpointError(502,"Carrier inventory is unavailable. Try again.");
      for (const item of response.data.data || []) {
        if (!phone.test(item.phone_number) || !item.features?.some((f:any) => f.name === "sms") ||
          item.cost_information?.currency !== "USD" || item.requirements_met === false || item.best_effort === true) continue;
        const base = money(item.cost_information.monthly_cost);
        const supplierSetup = money(item.cost_information.upfront_cost);
        const setup = supplierSetup; // Preserve the current retail setup charge.
        if (base<=0) continue;
        const fee = money(await this.rpc("resolve_app_fee",{p_item:"intelcallfee",p_tier:tier,p_base_amount:base}));
        const total = Math.max(money(base + fee),money(policy.minimum_monthly_usd));
        const [quote] = await this.db("second_number_orders","POST",{ user_id:userId,phone_number:item.phone_number,
          country_code:country,country_name:policy.country_name,number_type:policy.number_type,
          wholesale_monthly_usd:base,wholesale_setup_usd:supplierSetup,quote_contract_version:1,monthly_fee_usd:total,service_fee_usd:money(total-base),setup_fee_usd:setup,
          terms:{ version:policy.terms_version,usage:policy.usage_terms,kyc_status:policy.kyc_status,billing_period_days:30 } });
        result.push({ quote_id:quote.id,phone_number:item.phone_number,formatted_number:item.phone_number,country_code:country,
          phone_number_type:policy.number_type,features:["sms"],
          total_monthly_usd:total,setup_fee_usd:setup,total_due_usd:money(total+setup),currency:"USD",
          quote_expires_at:quote.expires_at,usage_terms:policy.usage_terms,billing_period_days:30 });
      }
    }
    return { success:true,numbers:result };
  }
  async order(userId: string, id: string) {
    if (!uuid.test(id || "")) throw new EndpointError(400,"Invalid order.");
    const rows = await this.db(`second_number_orders?id=eq.${id}&user_id=eq.${userId}&select=id,state,did_id,phone_number,monthly_fee_usd,setup_fee_usd,auto_renew,created_at`);
    if (!rows.length) throw new EndpointError(404,"Order unavailable.");
    return { success:true,order:rows[0] };
  }
  async purchase(userId: string, input: any) {
    if (!uuid.test(input.quote_id || "")) throw new EndpointError(400,"Refresh available numbers before purchasing.");
    // Check binding configuration before funds are reserved.
    const profile = await this.config("TELNYX_MESSAGING_PROFILE_ID");
    const [quote] = await this.db(`second_number_orders?id=eq.${input.quote_id}&user_id=eq.${userId}&select=*`);
    if (!quote) throw new EndpointError(404,"Order unavailable.");
    let monthly: number | null = null, setup: number | null = null;
    if (quote.state === "quoted") {
      if (!await this.pilotAllowed(userId)) throw new EndpointError(503,"Number purchases are awaiting validation.");
      // Repeat an exact-number supplier search just before reserving. Client
      // amounts and the earlier inventory page never authorize supplier spend.
      const q = new URLSearchParams({"filter[country_code]":quote.country_code,
        "filter[phone_number_type]":quote.number_type,"filter[phone_number][starts_with]":quote.phone_number,"filter[limit]":"10"});
      const available = await this.carrier(`available_phone_numbers?${q}`);
      const matches = Array.isArray(available.data.data) ? available.data.data.filter((n:any)=>n.phone_number===quote.phone_number) : [];
      const item = matches[0];
      if (available.status!==200 || matches.length!==1 || item.cost_information?.currency!=="USD" ||
        !item.features?.some((f:any)=>f.name==="sms") || item.requirements_met===false || item.best_effort===true) {
        throw new EndpointError(409,"Number availability changed. Refresh available numbers.");
      }
      monthly=money(item.cost_information.monthly_cost); setup=money(item.cost_information.upfront_cost);
      if (monthly!==Number(quote.wholesale_monthly_usd) || setup!==Number(quote.wholesale_setup_usd))
        throw new EndpointError(409,"Number price changed. Refresh available numbers.");
    }
    const start = await this.rpc("authorize_second_number_purchase",{p_user_id:userId,p_quote_id:input.quote_id,
      p_auto_renew:input.auto_renew === true,p_supplier_monthly:monthly,p_supplier_setup:setup});
    if (start.submit) {
      const [stored] = await this.db(`second_number_orders?id=eq.${start.order_id}&select=*`);
      try {
        const response = await this.carrier("number_orders","POST",{ phone_numbers:[{ phone_number:stored.phone_number }],
          messaging_profile_id:profile,customer_reference:stored.id });
        if (response.status >= 200 && response.status < 300 && response.data.data?.id) {
          await this.db(`second_number_orders?id=eq.${stored.id}&state=eq.submitting`,"PATCH",
            {state:"provisioning",provider_order_id:response.data.data.id,updated_at:new Date().toISOString()});
        } else if ([400,401,403,404,422].includes(response.status)) {
          // Explicit rejection of this single POST is safe to release; ambiguous
          // timeouts, 409, 429 and 5xx are reconciled by customer_reference.
          await this.rpc("fail_second_number_purchase",{p_order_id:stored.id});
        } else {
          await this.db(`second_number_orders?id=eq.${stored.id}&state=eq.submitting`,"PATCH",{state:"reconciliation"});
        }
      } catch (_) {
        // The durable submitting marker survives every ambiguous exception.
      }
    }
    return await this.order(userId,start.order_id);
  }
  async reconcile(stored: any) {
    const ref = stored.id;
    const found = stored.provider_order_id
      ? await this.carrier(`number_orders/${encodeURIComponent(stored.provider_order_id)}`)
      : await this.carrier(`number_orders?filter[customer_reference]=${encodeURIComponent(ref)}&page[size]=10`);
    if (found.status !== 200) return;
    const list = stored.provider_order_id ? [found.data.data] : found.data.data;
    if (!Array.isArray(list) || list.length !== 1) return; // Never submit again on an empty/uncertain result.
    const order = list[0];
    if (!order?.id || order.customer_reference !== ref || !order.phone_numbers || order.phone_numbers.length!==1 ||
      order.phone_numbers[0].phone_number !== stored.phone_number || (stored.provider_order_id && stored.provider_order_id!==order.id)) return;
    if (["failure","cancelled"].includes(order.status)) {
      const inventory = await this.carrier(`phone_numbers?filter[phone_number]=${encodeURIComponent(stored.phone_number.replace(/^\+/,""))}`);
      if (inventory.status!==200 || !Array.isArray(inventory.data.data) || inventory.data.data.length!==0) return;
      await this.rpc("fail_second_number_purchase",{p_order_id:ref}); return;
    }
    if (order.status!=="success" || order.requirements_met !== true) return;
    const inventory = await this.carrier(`phone_numbers?filter[phone_number]=${encodeURIComponent(stored.phone_number.replace(/^\+/,""))}`);
    if (inventory.status!==200 || inventory.data.data?.length!==1) return;
    const number = inventory.data.data[0];
    if (number.phone_number!==stored.phone_number || !number.id || number.status!=="active") return;
    const profile = await this.config("TELNYX_MESSAGING_PROFILE_ID");
    const bind = await this.carrier(`phone_numbers/${encodeURIComponent(number.id)}/messaging`,"PATCH",{messaging_profile_id:profile});
    if (bind.status!==200 || bind.data.data?.messaging_profile_id!==profile) return;
    await this.rpc("finish_second_number_purchase",{p_order_id:ref,p_provider_order_id:order.id,p_provider_sid:number.id});
  }
  async sweep() {
    const deadline=Date.now()+55000;
    let pending = 0;
    await this.rpc("process_second_number_renewals",{p_limit:50});
    // Stop ongoing supplier obligations before spending time on new orders.
    const releases = Date.now()<deadline ? await this.rpc("claim_second_number_releases",{p_limit:3}) : [];
    for (const item of releases) {
      if(Date.now()>=deadline)break;
      let confirmed = false;
      try {
        let sid=item.provider_sid;
        if(!sid) {
          const lookup=await this.carrier(`phone_numbers?filter[phone_number]=${encodeURIComponent(item.phone_number.replace(/^\+/,""))}`);
          if(lookup.status===200 && lookup.data.data?.length===1 && lookup.data.data[0].phone_number===item.phone_number) {
            sid=lookup.data.data[0].id;
            if(sid) await this.db(`virtual_did_numbers?id=eq.${item.id}&provider_sid=is.null&release_claim=eq.${item.release_claim}`,"PATCH",{provider_sid:sid});
          }
        }
        if(!sid)throw new EndpointError(503,"Legacy number ownership requires reconciliation");
        const current = await this.carrier(`phone_numbers/${encodeURIComponent(sid)}`);
        if (current.status===404) {
          const remaining=await this.carrier(`phone_numbers?filter[phone_number]=${encodeURIComponent(item.phone_number.replace(/^\+/,""))}`);
          confirmed=remaining.status===200 && Array.isArray(remaining.data.data) &&
            !remaining.data.data.some((n:any)=>n.phone_number===item.phone_number);
        }
        else if (current.status===200 && current.data.data?.phone_number===item.phone_number) {
          const deleted = await this.carrier(`phone_numbers/${encodeURIComponent(sid)}`,"DELETE");
          if (deleted.status>=200 && deleted.status<300) {
            const check = await this.carrier(`phone_numbers/${encodeURIComponent(sid)}`);
            if(check.status===404) {
              const remaining=await this.carrier(`phone_numbers?filter[phone_number]=${encodeURIComponent(item.phone_number.replace(/^\+/,""))}`);
              confirmed=remaining.status===200 && Array.isArray(remaining.data.data) &&
                !remaining.data.data.some((n:any)=>n.phone_number===item.phone_number);
            }
          }
        }
      } catch (_) { /* Retry a retained, claimed release after bounded backoff. */ }
      await this.rpc("finish_second_number_release",{p_did_id:item.id,p_claim:item.release_claim,p_confirmed:confirmed});
    }
    const orders = await this.db("second_number_orders?state=in.(submitting,provisioning,reconciliation)&select=*&order=updated_at&limit=5");
    for (const order of orders) {
      if(Date.now()>=deadline)break;
      try { await this.reconcile(order); } catch (_) { pending++; }
      // Rotate checked pending orders so a slow carrier order cannot starve
      // newer purchases. created_at retains the original provisioning age.
      try {
        await this.db(`second_number_orders?id=eq.${order.id}&state=in.(submitting,provisioning,reconciliation)`,"PATCH",{updated_at:new Date().toISOString()});
      } catch (_) { pending++; }
    }
    const due = await this.db("virtual_did_numbers?lifecycle_managed=eq.true&status=eq.suspended&auto_renew=eq.true&select=id,provider_sid,phone_number,renews_at&order=updated_at&limit=10");
    for (const item of due) {
      if (Date.now()>=deadline) break;
      try {
        if (!item.provider_sid) continue;
        const owned=await this.carrier(`phone_numbers/${encodeURIComponent(item.provider_sid)}`);
        if (owned.status!==200 || owned.data.data?.id!==item.provider_sid ||
          owned.data.data.phone_number!==item.phone_number || owned.data.data.status!=="active") continue;
        const profile=await this.config("TELNYX_MESSAGING_PROFILE_ID");
        const binding=await this.carrier(`phone_numbers/${encodeURIComponent(item.provider_sid)}/messaging`);
        if (binding.status!==200 || binding.data.data?.messaging_profile_id!==profile) continue;
        await this.rpc("settle_second_number_renewal",{p_did_id:item.id,p_period_start:item.renews_at,p_provider_sid:item.provider_sid});
      } catch (_) { pending++; } // Failed capture never extends or activates service.
      finally {
        await this.db(`virtual_did_numbers?id=eq.${item.id}&status=eq.suspended`,"PATCH",{updated_at:new Date().toISOString()}).catch(()=>{pending++;});
      }
    }
    return {success:true,orders_checked:orders.length,releases_checked:releases.length,errors:pending};
  }
}
