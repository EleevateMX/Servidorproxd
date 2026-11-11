// Estado que envía el servidor (pxd_orgs/server/main.lua → view). La interfaz solo lo pinta.
export interface Font { id: string; label: string; family: string }
export interface Identity {
  id: number; slug: string; name: string; type: string; color: string; font: string; fontFamily: string; motto?: string; emblem: string;
}
export interface Perms { invite: boolean; manage: boolean; funds: boolean; identity: boolean; leader: boolean }
export interface Member { citizenid: string; name: string; grade: number; gradeName: string; online: boolean; leader: boolean }
export interface HistoryRow { action: string; actor_name?: string; target?: string; amount?: number; detail?: string; created_at: number }
export interface OrgView extends Identity {
  typeLabel: string; status: string; reputation: number; level: number; levelRep: number; nextRep?: number; slots: number;
  grade: number; gradeName: string; perms: Perms; members: Member[]; funds?: number | null; fundMethods: Record<string, boolean>;
  invites: { citizenid: string; name: string; by: string; expires: number }[]; nearby: { id: number; name: string }[];
  grades: { level: number; name: string }[]; history?: HistoryRow[];
}
export interface InviteIn extends Identity { by: string; expires: number; typeLabel?: string }
export interface FoundingReq {
  creator: string; by: string; name: string; type: string; typeLabel?: string; color: string; font: string; emblem: string; accepted: boolean; expires: number;
}
export interface Draft {
  name: string; type: string; typeLabel?: string; identity: { color: string; font: string; motto?: string; emblem: string };
  founders: { citizenid: string; name: string; accepted: boolean }[]; count: number; needed: number; expires: number; cost: number;
}
export interface PendingView extends Identity { typeLabel: string; founders: { citizenid?: string; name: string }[]; cost: number; createdAt?: number }
export interface Requirement { id: string; ok: boolean; label: string; detail: string }
export interface CreateInfo {
  types: { id: string; label: string }[]; colors: string[]; fonts: Font[]; requirements: Requirement[]; staff: boolean; cost: number;
  minFounders: number; nameMin: number; nameMax: number; mottoMax: number; approval: 'staff' | 'auto'; nearby: { id: number; name: string }[]; blocked: boolean;
}
export interface DirEntry { id: number; name: string; typeLabel: string; color: string; font: string; fontFamily: string; emblem: string; level: number; motto?: string }
export interface State {
  me: { name: string; citizenid: string }; command: string; org?: OrgView; otherGang?: string; invites: InviteIn[]; founding: FoundingReq[];
  draft?: Draft; pending?: PendingView; create?: CreateInfo; identityOptions?: { colors: string[]; fonts: Font[]; mottoMax: number };
  directory: DirEntry[]; staff?: { pending: PendingView[] };
}
export interface RpcResult { ok: boolean; message?: string; error?: string; state?: State }
