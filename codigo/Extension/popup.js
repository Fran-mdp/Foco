async function draw() {
  const {configuration,session,connectionError}=await chrome.storage.local.get(['configuration','session','connectionError']);
  const root=document.getElementById('sites');root.replaceChildren();
  const unique=new Map((configuration?.sites||[]).filter(validSite).map(site=>[site.host,site]));
  if(!unique.size) root.textContent='Todavía no hay sitios. Agregalos desde la app Foco.';
  const active=session && (session.duration==null || session.startedAt+session.duration>Date.now()/1000);
  for(const site of unique.values()) {
    const origin=originFor(site);
    const granted=await chrome.permissions.contains({origins:[origin]});
    const row=document.createElement('div');row.className='site';
    const labels=document.createElement('div');
    const name=document.createElement('div');name.className='name';name.textContent=site.host;
    const scope=document.createElement('div');scope.className='scope';scope.textContent=granted?'Permiso autorizado':'Acceso solo a este dominio y sus subdominios';
    labels.append(name,scope);
    const button=document.createElement('button');button.textContent=granted?'Quitar permiso':'Autorizar';button.disabled=!!active;
    button.addEventListener('click',()=>{
      // Request is invoked directly from a user gesture, before any await.
      const operation=granted?chrome.permissions.remove({origins:[origin]}):chrome.permissions.request({origins:[origin]});
      operation.then(result=>{document.getElementById('status').textContent=result?'Permiso actualizado.':'No se cambió el permiso.';return draw();}).catch(error=>{document.getElementById('status').textContent='Chrome no cambió el permiso: '+String(error.message||'revisá la configuración').slice(0,200);});
    });
    row.append(labels,button);root.append(row);
  }
  if(active) document.getElementById('status').textContent='Terminá la sesión antes de cambiar permisos.';
  else if(connectionError) document.getElementById('status').textContent='Abrí Foco y revisá la conexión con este perfil.';
}
chrome.storage.onChanged.addListener(changes=>{if(changes.configuration||changes.session)draw();});
draw();
