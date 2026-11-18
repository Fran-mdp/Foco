const fs=require('node:fs');const vm=require('node:vm');const assert=require('node:assert/strict');
(async()=>{
 let permitted=false;let dynamic=[];let messages=[];
 const event={addListener(){}};
 let revoked=[];let expiration=null;
 const chrome={
  permissions:{contains:async()=>permitted,remove:async x=>{revoked.push(...x.origins);return true},onAdded:event,onRemoved:event},
  runtime:{onStartup:event,onInstalled:event},
  declarativeNetRequest:{getDynamicRules:async()=>dynamic,updateDynamicRules:async x=>{dynamic=x.addRules}},
  storage:{local:{set:async()=>{}}},
  alarms:{clear:async name=>{if(name==='expire')expiration=null},create:async(name,value)=>{if(name==='expire')expiration=value.when},onAlarm:event},
  action:{setBadgeText:async()=>{},setBadgeBackgroundColor:async()=>{}},
  tabs:{query:async()=>[],update:async()=>{}}
 };
 const context=vm.createContext({chrome,Date,URL,crypto:require('node:crypto').webcrypto,setInterval(){},importScripts(){}});
 vm.runInContext(fs.readFileSync(__dirname+'/../Extension/rules.js','utf8'),context);
 const worker=fs.readFileSync(__dirname+'/../Extension/worker.js','utf8').replace(/connect\(\);\s*$/,'');
 vm.runInContext(worker+';globalThis.sync=syncConfiguration;globalThis.apply=applySession;globalThis.heartbeat=ack;globalThis.bind=(p)=>{port=p;config={sites:[{host:"example.com",path:"/"}]};profile="test"};',context);
 context.bind({postMessage:m=>messages.push(m)});
 const session={id:'current',startedAt:Date.now()/1000,duration:60,sites:[{host:'example.com',path:'/'}]};
 await context.apply(session);assert(messages.at(-1).error);assert.equal(dynamic.length,0);
 await context.heartbeat();assert(messages.at(-1).error,'Heartbeat must not erase a permission failure');
 permitted=true;await context.apply(session);assert(!messages.at(-1).error);assert.equal(messages.at(-1).appliedID,'current');assert.equal(dynamic.length,1);
 const paused={...session,startedAt:Date.now()/1000-120,pausedAt:Date.now()/1000-110};
 await context.apply(paused);assert.equal(dynamic.length,1);assert.equal(expiration,null,'Paused session cancels expiry alarm');assert.equal(messages.at(-1).appliedID,'current');
 const resumed={...session,pauses:[{start:session.startedAt+10,end:session.startedAt+40}]};
 await context.apply(resumed);assert.equal(expiration,(session.startedAt+90)*1000,'Resumed session schedules shifted expiry');
 permitted=false;await context.apply(null);assert.equal(dynamic.length,0);assert.equal(messages.at(-1).appliedID,'');assert(!messages.at(-1).error);
 await context.sync({sites:[],applications:[]});assert.deepEqual(revoked,['*://*.example.com/*']);
 console.log('Worker state checks passed: denied permission never confirms blocking, errors persist across heartbeats, recovery and cleanup.');
})().catch(e=>{console.error(e);process.exit(1)});
