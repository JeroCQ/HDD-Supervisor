/**
 * Shared server foundation for HDD Edge Functions. It authenticates Supabase users/admins,
 * initializes the service client, validates requests, calls Gemini generation/embedding APIs,
 * and defines jurisdiction rules. It interacts with Auth, Postgres, private Storage and Gemini,
 * sitting between every browser action and the canonical RAG data.
 */
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { GoogleGenAI } from "npm:@google/genai@1.17.0";
export const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type"};
export const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});

/** Returns the service client from server-only secrets; throws on incomplete hosted configuration. */
export function serviceClient():SupabaseClient{const url=Deno.env.get("SUPABASE_URL"),key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");if(!url||!key)throw new Error("Server Supabase configuration missing");return createClient(url,key,{auth:{persistSession:false}})}
/** Verifies the bearer JWT with Supabase Auth and optionally checks the trusted profiles admin bit. */
export async function requireUser(req:Request,admin=false){const token=req.headers.get("Authorization")?.replace(/^Bearer\s+/i,"");if(!token)throw new Error("Authentication required");const db=serviceClient();const {data,error}=await db.auth.getUser(token);if(error||!data.user)throw new Error("Invalid session");if(admin){const {data:profile}=await db.from("profiles").select("is_admin").eq("id",data.user.id).single();if(!profile?.is_admin)throw new Error("Administrator role required")}return {user:data.user,db}}
/** Builds the only AI client. GEMINI_API_KEY never crosses this server boundary or enters a database row. */
export function gemini(){const key=Deno.env.get("GEMINI_API_KEY");if(!key)throw new Error("GEMINI_API_KEY is not configured");return new GoogleGenAI({apiKey:key})}
/** Embeds text with Gemini at exactly 1,536 dimensions to match kb_chunks vector(1536). */
export async function embed(text:string,taskType:"RETRIEVAL_QUERY"|"RETRIEVAL_DOCUMENT"="RETRIEVAL_QUERY"){const response=await gemini().models.embedContent({model:"gemini-embedding-001",contents:text,config:{outputDimensionality:1536,taskType}});const values=response.embeddings?.[0]?.values;if(!values||values.length!==1536)throw new Error("Gemini returned an unexpected embedding dimension");return values}
/** Produces stable SHA-256 hex hashes used to avoid re-embedding unchanged source content. */
export async function hash(text:string){const bytes=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(text));return [...new Uint8Array(bytes)].map(b=>b.toString(16).padStart(2,"0")).join("")}
/** Infers only explicit jurisdiction/location signals; UNKNOWN is retained instead of guessing site rights. */
export function classify(query:string,projectCode?:string){const q=query.toLowerCase();const spanish=/[¿¡áéíóúñ]|\b(podemos|dueño|qué)\b/i.test(q);const explicitProvo=q.includes("provo");const udot=/\budot\b|state highway|encroachment permit/.test(q);return {language:spanish?"es":"en",intent:/permission|permiso|property|propiedad/.test(q)?"ACCESS_AUTHORITY":/damage|dañ/.test(q)?"DAMAGE":"FIELD_GUIDANCE",jurisdiction:explicitProvo?"PROVO":projectCode?"SARATOGA_SPRINGS":null,project_code:projectCode??null,location_type:udot?"UDOT_ROW":"UNKNOWN",objection_type:/lawn|property|propiedad/.test(q)?"ACCESS":null,requires_legal_authority:/can |permission|damage|permit|podemos/.test(q),requires_project_specific_authority:/permission|property|propiedad/.test(q),requires_restoration:/sprinkler|restore|damage/.test(q),requires_safety:/pothol|tolerance|tolerancia/.test(q),requires_technical:/bore|perfor/.test(q),requires_deescalation:/lawn|salgamos|dueño/.test(q)} }
