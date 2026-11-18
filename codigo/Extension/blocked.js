// Original reminders, selected locally. No attributed quotes or remote services.
const reminders = [
  'No necesitás hacerlo perfecto. Solo dar el próximo paso.',
  'Tu atención es valiosa. Usala en eso que elegiste construir.',
  'Cinco minutos de acción valen más que esperar el momento perfecto.',
  'Volvé a una tarea pequeña. El avance empieza ahí.',
  'La disciplina también es esto: volver, una vez más.',
  'No hace falta tener ganas para dar el primer paso.',
  'Ese futuro que querés se construye con ratos como este.',
  'Una distracción menos. Un paso más hacia lo que te importa.',
  'Hoy no tenés que resolver todo. Solo seguir con lo que empezaste.',
  'Aprender algo difícil lleva tiempo. Este rato cuenta.',
  'Lo que practicás hoy se vuelve más fácil mañana.',
  'Elegiste concentrarte por una razón. Dale unos minutos más.'
];
let session;
function clock(value) {
  const n = Math.max(0, Math.floor(value));
  return n >= 3600
    ? `${Math.floor(n / 3600)}:${String(Math.floor(n / 60) % 60).padStart(2, '0')}:${String(n % 60).padStart(2, '0')}`
    : `${String(Math.floor(n / 60)).padStart(2, '0')}:${String(n % 60).padStart(2, '0')}`;
}
function draw() {
  const now = Date.now() / 1000;
  const active = sessionActive(session, now);
  document.getElementById('links').hidden = !!active;
  document.getElementById('motivation').hidden = !active;
  if (active) {
    document.getElementById('heading').textContent = 'Este rato es para vos.';
    document.getElementById('intro').textContent = 'Este sitio está en tu lista de bloqueo. Volvé a eso que elegiste hacer.';
    document.getElementById('status').textContent = session.pausedAt != null ? 'SESIÓN EN PAUSA · BLOQUEO ACTIVO' : session.firm ? 'MODO FIRME · SEGUÍ CON LO TUYO' : 'SESIÓN DE CONCENTRACIÓN';
    document.getElementById('elapsed').textContent = clock(sessionElapsed(session, now));
    document.getElementById('remaining').textContent = session.duration != null
      ? `Quedan ${clock(session.duration - sessionElapsed(session, now))}` : 'Tiempo de concentración';
    document.getElementById('tip').textContent = 'Podés seguir usando el resto de Chrome normalmente.';
  } else {
    document.getElementById('heading').textContent = 'Un rato bien invertido.';
    document.getElementById('intro').textContent = 'Terminaste tu sesión. Tu tiempo de concentración quedó guardado en Foco.';
    document.getElementById('status').textContent = 'TU SESIÓN TERMINÓ';
    document.getElementById('elapsed').textContent = '✓';
    document.getElementById('remaining').textContent = 'Ya podés volver a navegar.';
    document.getElementById('tip').textContent = 'Si tenés otro bloqueador activo, también necesitás terminar esa sesión.';
  }
}
chrome.storage.local.get(['session', 'lastReminder']).then(data => {
  session = data.session;
  const candidates = reminders.map((_, index) => index).filter(index => index !== data.lastReminder);
  const random = new Uint32Array(1);
  crypto.getRandomValues(random);
  const index = candidates[random[0] % candidates.length];
  document.getElementById('quote').textContent = reminders[index];
  chrome.storage.local.set({ lastReminder: index });
  draw();
});
chrome.storage.onChanged.addListener(changes => {
  if (changes.session) { session = changes.session.newValue; draw(); }
});
setInterval(draw, 1000);
