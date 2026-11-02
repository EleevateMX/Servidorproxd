// Quién puede hacer qué. Puro: recibe las claves de rol del miembro.
// El bot comprueba siempre en el servidor, aunque Discord ya oculte el comando.
import { STAFF_ROLES, SELF_ROLES } from './template.js';

export const isStaff = (roleKeys, isAdmin = false) => isAdmin || roleKeys.some((k) => STAFF_ROLES.includes(k));

// Fundador y Administración publican cualquier anuncio; Eventos solo eventos.
export function canAnnounce(roleKeys, kind, isAdmin = false) {
  if (isAdmin || roleKeys.includes('founder') || roleKeys.includes('admin')) return true;
  return kind === 'events' && roleKeys.includes('events');
}

export const canSelfAssign = (key) => SELF_ROLES.includes(key);

export function canCloseTicket({ roleKeys, isAdmin = false, userId, ownerId }) {
  return isStaff(roleKeys, isAdmin) || (Boolean(ownerId) && userId === ownerId);
}

// Un ticket abierto por persona.
export function openTicketOf(tickets, userId) {
  return Object.entries(tickets ?? {}).find(([, t]) => t.ownerId === userId && !t.closed)?.[0] ?? null;
}

// Nombre del hilo privado del ticket: sin caracteres raros y como mucho 100 (límite de Discord).
export function ticketName(username, number) {
  const clean = String(username ?? '').toLowerCase().replace(/[^a-z0-9_.-]/g, '').slice(0, 32) || 'ciudadano';
  return `🎫 ticket-${String(number).padStart(4, '0')}-${clean}`.slice(0, 100);
}
