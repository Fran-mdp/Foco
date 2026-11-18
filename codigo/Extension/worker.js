/* Local-only native connection. Rules are evaluated by Chrome, not page scripts. */
importScripts('rules.js');
const HOST = 'local.foco.bridge';
let port = null;
let profile;
let reconnecting = false;
let applying = Promise.resolve();
let current = null;
let appliedID = '';
let lastError;
let config = {sites:[],applications:[]};

async function syncConfiguration(next) {
  const previousHosts=new Set((config.sites||[]).filter(validSite).map(site=>site.host));
  const nextHosts=new Set((next.sites||[]).filter(validSite).map(site=>site.host));
  const removed=[...previousHosts].filter(host=>!nextHosts.has(host));
  config=next;
  await chrome.storage.local.set({configuration:config});
  if(removed.length) await chrome.permissions.remove({origins:removed.map(host=>originFor({host}))});
}
async function permittedHosts() {
  const hosts = [...new Set((config.sites || []).filter(validSite).map(site => site.host))];
  const results = await Promise.all(hosts.map(async host => await chrome.permissions.contains({origins:[originFor({host})]}) ? host : null));
  return results.filter(Boolean);
}
async function ack() {
  try { port?.postMessage({op:'ack',profile,appliedID,grantedHosts:await permittedHosts(),...(lastError?{error:lastError}:{})}); } catch (_) {}
}
async function applySession(session) {
  current = session || null;
  try {
    const rules = rulesFor(current);
    const sites = rules.length ? sessionSites(current) : [];
    const missing = [];
    for (const site of sites) {
      if (!await chrome.permissions.contains({origins:[originFor(site)]})) missing.push(site.host);
    }
    if (missing.length) throw new Error('Missing host permission');
    const existing = await chrome.declarativeNetRequest.getDynamicRules();
    if (JSON.stringify(existing) !== JSON.stringify(rules)) {
      await chrome.declarativeNetRequest.updateDynamicRules({removeRuleIds:existing.map(rule=>rule.id),addRules:rules});
    }
    const active = sessionActive(current);
    await chrome.storage.local.set({session:active?current:null});
    await chrome.alarms.clear('expire');
    const deadline = sessionDeadline(current);
    if (active && deadline != null) await chrome.alarms.create('expire',{when:deadline*1000});
    appliedID = active ? current.id : '';
    lastError = undefined;
    await chrome.action.setBadgeText({text:active?(current.pausedAt != null?'Ⅱ':'ON'):''});
    await chrome.action.setBadgeBackgroundColor({color:'#247D6C'});
    await ack();
    if (sites.length) {
      // Only URLs authorized by the user are queried. Redirect only matching paths.
      const tabs=await chrome.tabs.query({url:[...new Set(sites.map(originFor))]});
      for (const tab of tabs) {
        if (tab.id==null || !tab.url) continue;
        const url=new URL(tab.url);
        if (sites.some(site => (url.hostname===site.host || url.hostname.endsWith('.'+site.host)) &&
          (site.path==='/' || url.pathname===site.path || url.pathname.startsWith(site.path+'/')))) {
          try { await chrome.tabs.update(tab.id,{url:chrome.runtime.getURL('blocked.html')}); } catch (_) { /* tab may have closed */ }
        }
      }
    }
  } catch (_) {
    lastError='No se pudo aplicar el bloqueo. Revisá los permisos de los sitios en el complemento Foco.';
    await ack();
  }
}
function queueApply(session) { applying=applying.catch(()=>{}).then(()=>applySession(session)); }
async function connect() {
  if(port||reconnecting) return;
  reconnecting=true;
  try {
    const data=await chrome.storage.local.get(['profile','session','configuration']);
    profile=data.profile||crypto.randomUUID();
    config=data.configuration||config;
    if(!data.profile) await chrome.storage.local.set({profile});
    if(data.session) queueApply(data.session);
    port=chrome.runtime.connectNative(HOST);
    port.onMessage.addListener(message=>{
      if(message.error) {
        chrome.action.setBadgeText({text:'!'});
        chrome.storage.local.set({connectionError:message.error});
        return;
      }
      chrome.storage.local.remove('connectionError');
      applying=applying.catch(()=>{}).then(async()=>{
        if(message.configuration) await syncConfiguration(message.configuration);
        await applySession(message.session);
      });
    });
    port.onDisconnect.addListener(()=>{void chrome.runtime.lastError;port=null;});
    port.postMessage({op:'hello',profile});
  } finally {reconnecting=false;}
}
chrome.permissions.onAdded.addListener(()=>{queueApply(current);ack();});
chrome.permissions.onRemoved.addListener(()=>{queueApply(current);ack();});
chrome.alarms.onAlarm.addListener(async alarm=>{
  if(alarm.name==='expire') {const {session}=await chrome.storage.local.get('session');queueApply(session);}
  if(!port) connect();
});
chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
chrome.alarms.create('reconnect',{periodInMinutes:.5});
setInterval(()=>{if(port)ack();else connect();},3000);
connect();
