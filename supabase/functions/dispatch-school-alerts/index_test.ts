import { handler } from './index.ts';
const assert = (v: boolean) => { if (!v) throw new Error('Assertion failed'); };
Deno.test('dispatcher rejects non-POST requests',async()=>{
  const result = await handler(new Request('http://localhost',{method:'GET'}));
  assert(result.status===405);
});
Deno.test('dispatcher fails closed without configured authentication',async()=>{
  Deno.env.delete('DISPATCH_SECRET');
  const result = await handler(new Request('http://localhost',{method:'POST'}));
  assert(result.status===401);
});
Deno.test('ordinary app requests cannot dispatch notifications',async()=>{
  Deno.env.set('DISPATCH_SECRET','isolated-test-only-value');
  const result = await handler(new Request('http://localhost',{method:'POST',headers:{Authorization:'Bearer wrong-value'}}));
  assert(result.status===401);
  Deno.env.delete('DISPATCH_SECRET');
});
