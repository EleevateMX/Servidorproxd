// Modo demostración (index.html?demo=1&view=…): datos simulados para revisar la interfaz en un
// navegador y sacar capturas. No se usa dentro del juego.
import type { CreateInfo, Font, OrgView, PendingView, RpcResult, State } from './types';
import { setDemoHandler } from './nui';

const fonts: Font[] = [
  { id: 'sora', label: 'Próxima', family: 'Sora' }, { id: 'bebas', label: 'Cartel', family: 'PXO Bebas Neue' },
  { id: 'marker', label: 'Rotulador', family: 'PXO Permanent Marker' }, { id: 'bangers', label: 'Cómic', family: 'PXO Bangers' },
  { id: 'russo', label: 'Industrial', family: 'PXO Russo One' }, { id: 'pacifico', label: 'Caligrafía', family: 'PXO Pacifico' },
  { id: 'blackops', label: 'Plantilla', family: 'PXO Black Ops One' },
];
const colors = ['#5ce1ff', '#ff4fd8', '#ffc857', '#3fe08f', '#ff5472', '#9b7bff', '#ff8a3d', '#f2f5ff', '#2ec4b6', '#e63946', '#8ac926', '#1982c4', '#c77dff', '#b08968', '#adb5bd', '#ffd60a'];
const now = () => Math.floor(Date.now() / 1000);

const create = (over: Partial<CreateInfo> = {}): CreateInfo => ({
  types: [{ id: 'banda', label: 'Banda' }, { id: 'motoclub', label: 'Club de motos' }, { id: 'grupo', label: 'Grupo' }],
  colors, fonts, staff: false, cost: 25000, minFounders: 2, nameMin: 3, nameMax: 28, mottoMax: 60, approval: 'staff', blocked: false,
  requirements: [
    { id: 'level', ok: true, label: 'Nivel 3 de personaje', detail: 'Tienes nivel 7' },
    { id: 'cost', ok: true, label: 'Tasa de registro de $25000 (banco)', detail: 'Tienes $48210 en el banco' },
    { id: 'founders', ok: false, label: '2 fundadores en total, cerca de ti', detail: '1 de 2' },
  ],
  nearby: [{ id: 12, name: 'Bruno Salgado' }, { id: 27, name: 'Carolina Lima' }, { id: 31, name: 'Dante Ochoa' }],
  ...over,
});

const directory = [
  { id: 1, name: 'Los Reyes del Sur', typeLabel: 'Banda', color: '#ff4fd8', font: 'marker', fontFamily: 'PXO Permanent Marker', emblem: 'LRS', level: 3, motto: 'El sur manda' },
  { id: 2, name: 'Hermandad del Asfalto', typeLabel: 'Club de motos', color: '#ff8a3d', font: 'blackops', fontFamily: 'PXO Black Ops One', emblem: 'HA', level: 2 },
  { id: 3, name: 'Vinewood Social Club', typeLabel: 'Grupo', color: '#ffc857', font: 'pacifico', fontFamily: 'PXO Pacifico', emblem: 'VSC', level: 1, motto: 'Siempre arriba' },
  { id: 4, name: 'Costa Norte', typeLabel: 'Banda', color: '#3fe08f', font: 'bebas', fontFamily: 'PXO Bebas Neue', emblem: 'CN', level: 4 },
];

const pending: PendingView = {
  id: 9, slug: 'pxo_9', name: 'Barrio Bajo', type: 'banda', typeLabel: 'Banda', color: '#9b7bff', font: 'bangers', fontFamily: 'PXO Bangers', emblem: 'BB',
  motto: 'Desde abajo', founders: [{ citizenid: 'A1', name: 'Valentina Ríos' }, { citizenid: 'B2', name: 'Bruno Salgado' }], cost: 25000,
};

const org = (over: Partial<OrgView> = {}): OrgView => ({
  id: 1, slug: 'pxo_1', name: 'Los Reyes del Sur', type: 'banda', typeLabel: 'Banda', status: 'official', color: '#ff4fd8', font: 'marker',
  fontFamily: 'PXO Permanent Marker', motto: 'El sur manda', emblem: 'LRS', reputation: 2350, level: 3, levelRep: 1500, nextRep: 4000, slots: 16,
  grade: 4, gradeName: 'Líder', perms: { invite: true, manage: true, funds: true, identity: true, leader: true }, funds: 184500,
  fundMethods: { cash: true, bank: true },
  members: [
    { citizenid: 'A1', name: 'Valentina Ríos', grade: 4, gradeName: 'Líder', online: true, leader: true },
    { citizenid: 'B2', name: 'Bruno Salgado', grade: 3, gradeName: 'Mano derecha', online: true, leader: false },
    { citizenid: 'C3', name: 'Carolina Lima', grade: 2, gradeName: 'Veterano', online: false, leader: false },
    { citizenid: 'D4', name: 'Dante Ochoa', grade: 1, gradeName: 'Miembro', online: true, leader: false },
    { citizenid: 'E5', name: 'Emilia Vargas', grade: 1, gradeName: 'Miembro', online: false, leader: false },
    { citizenid: 'F6', name: 'Fabián Cruz', grade: 0, gradeName: 'Aspirante', online: true, leader: false },
    { citizenid: 'G7', name: 'Gabriela Montenegro de la Fuente', grade: 0, gradeName: 'Aspirante', online: false, leader: false },
  ],
  invites: [{ citizenid: 'H8', name: 'Héctor Mena', by: 'Bruno Salgado', expires: now() + 240 }],
  nearby: [{ id: 14, name: 'Irene Sosa' }, { id: 22, name: 'Joaquín Paredes' }],
  grades: [{ level: 0, name: 'Aspirante' }, { level: 1, name: 'Miembro' }, { level: 2, name: 'Veterano' }, { level: 3, name: 'Mano derecha' }, { level: 4, name: 'Líder' }],
  history: [
    { action: 'deposit', actor_name: 'Bruno Salgado', amount: 12000, detail: 'bank', created_at: now() - 600 },
    { action: 'promote', actor_name: 'Valentina Ríos', target: 'C3', detail: '1 → 2', created_at: now() - 4000 },
    { action: 'join', actor_name: 'Fabián Cruz', detail: 'invitación de Bruno Salgado', created_at: now() - 9000 },
  ],
  ...over,
});

const base = (over: Partial<State> = {}): State => ({
  me: { name: 'Valentina Ríos', citizenid: 'A1' }, command: 'org', invites: [], founding: [], directory, ...over,
});

function build(view: string): { state: State; section?: string; tab?: string } {
  switch (view) {
    case 'create': return { state: base({ create: create() }) };
    case 'draft': return { state: base({ create: create(), draft: { name: 'Barrio Bajo', type: 'banda', typeLabel: 'Banda',
      identity: { color: '#9b7bff', font: 'bangers', emblem: 'BB', motto: 'Desde abajo' },
      founders: [{ citizenid: 'B2', name: 'Bruno Salgado', accepted: true }, { citizenid: 'C3', name: 'Carolina Lima', accepted: false }],
      count: 2, needed: 2, expires: now() + 420, cost: 25000 } }) };
    case 'pending': return { state: base({ create: create(), pending }) };
    case 'org': return { state: base({ org: org(), identityOptions: { colors, fonts, mottoMax: 60 } }) };
    case 'org-funds': return { state: base({ org: org(), identityOptions: { colors, fonts, mottoMax: 60 } }), tab: 'funds' };
    case 'org-identity': return { state: base({ org: org(), identityOptions: { colors, fonts, mottoMax: 60 } }), tab: 'identity' };
    case 'org-invites': return { state: base({ org: org(), identityOptions: { colors, fonts, mottoMax: 60 } }), tab: 'invites' };
    case 'org-settings': return { state: base({ org: org(), identityOptions: { colors, fonts, mottoMax: 60 } }), tab: 'settings' };
    case 'member': return { state: base({ me: { name: 'Fabián Cruz', citizenid: 'F6' }, identityOptions: { colors, fonts, mottoMax: 60 },
      org: org({ grade: 0, gradeName: 'Aspirante', perms: { invite: false, manage: false, funds: false, identity: false, leader: false }, invites: [], nearby: [], history: undefined }) }) };
    case 'staff': return { state: base({ create: create({ staff: true, minFounders: 1, cost: 0 }), staff: { pending: [pending, { ...pending, id: 10, slug: 'pxo_10', name: 'Hijos de la Niebla',
      type: 'motoclub', typeLabel: 'Club de motos', color: '#adb5bd', font: 'blackops', emblem: 'HN', motto: undefined, founders: [{ citizenid: 'Z9', name: 'Zoe Ibarra' }, { citizenid: 'Y8', name: 'Yago Prieto' }, { citizenid: 'X7', name: 'Ximena Luján' }] }] } }), section: 'staff' };
    default: return { state: base({ create: create(),
      invites: [{ id: 2, slug: 'pxo_2', name: 'Hermandad del Asfalto', type: 'motoclub', typeLabel: 'Club de motos', color: '#ff8a3d', font: 'blackops', fontFamily: 'PXO Black Ops One', emblem: 'HA', by: 'Zoe Ibarra', expires: now() + 200 }],
      founding: [{ creator: 'Q1', by: 'Bruno Salgado', name: 'Barrio Bajo', type: 'banda', typeLabel: 'Banda', color: '#9b7bff', font: 'bangers', emblem: 'BB', accepted: false, expires: now() + 500 }] }) };
  }
}

export function start() {
  const params = new URLSearchParams(window.location.search);
  const view = params.get('view') ?? 'home';
  const built = build(view === 'create-form' ? 'create' : view);
  const reply = (action: string): RpcResult => {
    if (action === 'createStart') return { ok: true, message: 'Propuesta enviada a tus cofundadores.', state: build('draft').state };
    if (action === 'withdraw' || action === 'deposit') return { ok: true, message: 'Movimiento registrado.', state: built.state };
    if (action === 'dissolve' || action === 'leave') return { ok: true, message: 'Hecho.', state: base({ create: create() }) };
    if (action === 'kick') return { ok: false, error: 'No puedes dar ni cambiar ese rango.', state: built.state };
    return { ok: true, message: 'Hecho (demostración).', state: built.state };
  };
  setDemoHandler(reply);
  window.setTimeout(() => {
    window.postMessage({ action: 'open', state: built.state, section: built.section, tab: built.tab }, '*');
    // Vistas que necesitan un clic: el formulario de fundación y las ventanas de confirmación.
    window.setTimeout(() => {
      const click = (sel: string, text?: string) => {
        const els = Array.from(document.querySelectorAll<HTMLElement>(sel));
        (text ? els.find((e) => (e.textContent ?? '').includes(text)) : els[0])?.click();
      };
      if (view === 'create-form') click('.card--cta .btn--primary');
      if (params.get('modal') === 'kick') click('.btn--ghost-danger');
      if (params.get('modal') === 'dissolve') click('.btn--danger', 'Disolver');
      if (params.get('modal') === 'reject') click('.row__btns .btn', 'Rechazar');
    }, 120);
  }, 30);
}
