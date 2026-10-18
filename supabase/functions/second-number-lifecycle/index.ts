import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { EndpointError, requireService } from "../_shared/endpoint-auth.ts";
import { SecondNumbers } from "../_shared/second-number.ts";

serve(async (req: Request) => {
  if (req.method!=="POST") return new Response("Method not allowed",{status:405});
  try {
    const url=Deno.env.get("SUPABASE_URL")!;
    const key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    requireService(req,key);
    return Response.json(await new SecondNumbers(url,key).sweep());
  } catch (error) {
    return Response.json({error:error instanceof EndpointError ? error.message : "Number lifecycle processing unavailable"},
      {status:error instanceof EndpointError ? error.status : 503});
  }
});
