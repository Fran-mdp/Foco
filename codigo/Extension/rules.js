// Loaded by both the service worker and unit tests. No page content is read.
function validSite(site) {
  if (!site || typeof site.host !== 'string' || typeof site.path !== 'string') return false;
  if (site.host.length > 253 || !/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$/.test(site.host)) return false;
  if (site.host.split('.').some(label => label.length > 63) || site.host.split('.').every(label => /^\d+$/.test(label))) return false;
  return site.path.length <= 400 && /^\/(?:[A-Za-z0-9\-._~%!$&'()*+,;=:@/])*$/.test(site.path);
}
function escapeRegex(value) { return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
function sessionSites(session) {
  const legacy = ['youtube.com','instagram.com','youtu.be'].map(host => ({host,path:'/'}));
  if (session?.blockWhatsAppWeb) legacy.push({host:'web.whatsapp.com',path:'/'});
  const sites = session?.sites ?? legacy;
  if (!Array.isArray(sites) || sites.length > 100 || !sites.every(validSite)) throw new Error('Invalid sites');
  return sites;
}
function pausedSeconds(session) {
  return (session.pauses || []).reduce((sum, pause) => sum + Math.max(0, pause.end - pause.start), 0);
}
function sessionDeadline(session) {
  return !session || session.pausedAt != null || session.duration == null ? null : session.startedAt + session.duration + pausedSeconds(session);
}
function sessionElapsed(session, now = Date.now() / 1000) {
  return Math.max(0, Math.min((session.pausedAt ?? now) - session.startedAt - pausedSeconds(session), session.duration ?? Infinity));
}
function sessionActive(session, now = Date.now() / 1000) {
  const deadline = sessionDeadline(session);
  return !!session && (deadline == null || deadline > now);
}
function rulesFor(session, now = Date.now() / 1000) {
  if (!sessionActive(session, now)) return [];
  return sessionSites(session).map((site, i) => ({
    id: 1101+i, priority: 1,
    action: {type:'redirect',redirect:{extensionPath:'/blocked.html'}},
    condition: site.path === '/'
      ? {urlFilter:`||${site.host}^`,resourceTypes:['main_frame']}
      : {regexFilter:`^https?://([a-z0-9-]+\\.)*${escapeRegex(site.host)}${escapeRegex(site.path)}([/?#]|$)`,resourceTypes:['main_frame'],isUrlFilterCaseSensitive:true}
  }));
}
function originFor(site) { return `*://*.${site.host}/*`; }
