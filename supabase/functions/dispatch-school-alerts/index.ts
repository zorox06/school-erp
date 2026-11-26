// Server-only FCM dispatcher. No service account or privileged Supabase key is
// embedded in Flutter. Run from a trusted scheduler with DISPATCH_SECRET.
type QueueRow = { id: string; school_id: string; user_id: string; student_id: string | null;
  attendance_day: string | null; attendance_operation: string | null; notice_id: string | null;
  entity_id: string | null; category: 'absence' | 'notice' | 'homework' | 'message' | 'leave' | 'timetable' | 'emergency'; lease_id: string; attempts: number };
type Device = { token: string };
type ServiceAccount = { project_id: string; client_email: string; private_key: string };
const enc = new TextEncoder();
let googleToken: { value: string; expires: number } | undefined;
const b64 = (data: Uint8Array) => btoa(String.fromCharCode(...data)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
const jsonPart = (v: unknown) => b64(enc.encode(JSON.stringify(v)));
async function oauth(sa: ServiceAccount): Promise<string> {
  if (googleToken && googleToken.expires > Date.now() + 60000) return googleToken.value;
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${jsonPart({alg:'RS256',typ:'JWT'})}.${jsonPart({iss:sa.client_email,
    scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600})}`;
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const bytes = Uint8Array.from(atob(pem), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', bytes, {name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'}, false, ['sign']);
  const signature = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(unsigned)));
  const response = await fetch('https://oauth2.googleapis.com/token', {method:'POST',
    headers:{'Content-Type':'application/x-www-form-urlencoded'}, signal:AbortSignal.timeout(15000),
    body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:`${unsigned}.${b64(signature)}`})});
  if (!response.ok) throw new Error('google_auth');
  const token = await response.json();
  googleToken = {value:token.access_token,expires:Date.now()+Number(token.expires_in)*1000};
  return googleToken.value;
}
async function secretMatches(received: string, expected: string): Promise<boolean> {
  const a = new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(received)));
  const b = new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(expected)));
  let difference = 0;
  for (let i=0;i<a.length;i++) difference |= a[i]^b[i];
  return difference===0;
}

export async function handler(request: Request): Promise<Response> {
  if (request.method !== 'POST') return new Response('Method not allowed',{status:405});
  const secret = Deno.env.get('DISPATCH_SECRET');
  if (!secret || !await secretMatches(request.headers.get('Authorization') ?? '', `Bearer ${secret}`)) {
    return new Response('Unauthorized',{status:401});
  }
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const serviceAccount = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!url || !key || !serviceAccount) return new Response('Dispatcher is not configured',{status:503});
  const sa: ServiceAccount = JSON.parse(serviceAccount);
  const headers = {'apikey':key,'Authorization':`Bearer ${key}`,'Content-Type':'application/json'};
  async function rest<T>(resource: string, init: RequestInit = {}): Promise<T> {
    const result = await fetch(`${url}/rest/v1/${resource}`,{...init,headers:{...headers,...init.headers},signal:AbortSignal.timeout(15000)});
    if (!result.ok) throw new Error(`database_${result.status}`);
    return (result.status===204 || init.method==='PATCH' || init.method==='DELETE') ? undefined as T : result.json();
  }
  const q = (v: string) => encodeURIComponent(v);
  let sent = 0, retried = 0;
  try {
    const bearer = await oauth(sa);
    const rows = await rest<QueueRow[]>('rpc/erp_claim_notifications',{method:'POST',body:'{}'});
    for (const row of rows) {
      const rowFilter = `id=eq.${q(row.id)}&lease_id=eq.${q(row.lease_id)}`;
      try {
        const context = await rest<{allowed:boolean;muted?:boolean;defer_until?:string|null;can_approve?:boolean}>('rpc/erp_alert_context',{method:'POST',body:JSON.stringify({p_event:row.id})});
        if (!context.allowed || context.muted) {
          await rest(`erp_notification_outbox?${rowFilter}`,{method:'PATCH',body:JSON.stringify({delivered_at:new Date().toISOString(),last_error:context.muted?'user_preference':'access_revoked_or_superseded'})});
          continue;
        }
        if(context.defer_until && new Date(context.defer_until).getTime()>Date.now()){
          await rest(`erp_notification_outbox?${rowFilter}`,{method:'PATCH',body:JSON.stringify({lease_until:null,next_attempt:context.defer_until,last_error:'quiet_hours'})});
          continue;
        }
        const devices = await rest<Device[]>(`erp_device_tokens?select=token&school_id=eq.${q(row.school_id)}&user_id=eq.${q(row.user_id)}`);
        if (!devices.length) throw new Error('no_registered_device');
        const conversation = row.category === 'message' && row.entity_id
          ? (await rest<{conversation_id:string;erp_conversations:{student_id:string}}[]>(
              `erp_messages?select=conversation_id,erp_conversations!inner(student_id)&school_id=eq.${q(row.school_id)}&id=eq.${q(row.entity_id)}`))[0]
          : undefined;
        let failed = false;
        for (const device of devices) {
          const urgent = row.category==='absence'||row.category==='emergency';
          const emergency=row.category==='emergency';
          const approval=row.category==='leave'&&context.can_approve===true;
          // Generic lock-screen content; fetch student/notice details only after login.
          const response = await fetch(`https://fcm.googleapis.com/v1/projects/${q(sa.project_id)}/messages:send`,{
            method:'POST',headers:{'Authorization':`Bearer ${bearer}`,'Content-Type':'application/json'},signal:AbortSignal.timeout(15000),
            body:JSON.stringify({message:{fid:device.token,
              ...(approval?{}:{notification:{title:emergency?'Urgent school alert':row.category==='absence'?'School attendance update':'New school update',body:'Open Schoolday to securely view the update.'}}),
              data:{type:row.category,event_id:row.id,school_id:row.school_id,student_id:conversation?.erp_conversations.student_id??row.student_id??'',...(conversation ? {conversation_id:conversation.conversation_id} : {}),entity_id:row.entity_id??'',approve:approval?'true':'false',channel:emergency?'emergency':urgent?'urgent':'quiet'},
              android:{priority:urgent||approval?'high':'normal',ttl:'3600s',...(approval?{}:{notification:{channel_id:emergency?'school_emergency':urgent?'school_urgent':'school_quiet',tag:row.id,visibility:'PRIVATE'}})},
              apns:{headers:{'apns-priority':urgent?'10':'5','apns-push-type':'alert','apns-collapse-id':row.id},
                payload:{aps:{...(urgent?{sound:'default'}:{}),...(emergency?{'interruption-level':'time-sensitive'}:{}),...(approval?{category:'LEAVE_REQUEST',alert:{title:'School leave request',body:'Open Schoolday to review the request.'}}:{}),'thread-id':'schoolday'}}}}})});
          if (!response.ok) {
            const details = await response.json().catch(()=>({}));
            const unregistered = (details.error?.details ?? []).some((d:{errorCode?:string})=>d.errorCode==='UNREGISTERED');
            if (unregistered) {
              await rest(`erp_device_tokens?token=eq.${q(device.token)}&user_id=eq.${q(row.user_id)}`,{method:'DELETE'});
            } else { failed=true; }
          }
        }
        if (failed) throw new Error('fcm_retry');
        await rest(`erp_notification_outbox?${rowFilter}`,{method:'PATCH',body:JSON.stringify({delivered_at:new Date().toISOString(),last_error:null})});
        sent++;
      } catch (_) {
        await rest(`erp_notification_outbox?${rowFilter}`,{method:'PATCH',body:JSON.stringify({lease_until:null,
          next_attempt:new Date(Date.now()+Math.min(3600,30*2**Math.min(row.attempts,7))*1000).toISOString(),last_error:'delivery_retry'})});
        retried++;
      }
    }
    return Response.json({processed:rows.length,sent,retried});
  } catch (_) { return new Response('Dispatcher unavailable',{status:503}); }
}

if (import.meta.main) Deno.serve(handler);
