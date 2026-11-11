import { describe, expect, it } from 'vitest';
import { canKick, cleanEmblem, createBlocker, emblemFrom, fontFamily, gradeOptions, money, repProgress, sampleOf, timeLeft } from '../lib';
import type { CreateInfo, Member } from '../types';

const grades = [0, 1, 2, 3, 4].map((level) => ({ level, name: `R${level}` }));
const member = (grade: number, citizenid = 'X'): Member => ({ citizenid, name: 'N', grade, gradeName: `R${grade}`, online: true, leader: grade === 4 });
const perms = { invite: true, manage: true, funds: true, identity: true, leader: false };

describe('pxd_orgs · interfaz', () => {
  it('dinero y emblema', () => {
    expect(money(1234567)).toBe('$1.234.567');
    expect(money(undefined)).toBe('$0');
    expect(emblemFrom('Los Reyes del Sur')).toBe('LRD');
    expect(emblemFrom('Ñandú')).toBe('N');
    expect(emblemFrom('...')).toBe('ORG');
    expect(cleanEmblem('l-r 9x')).toBe('LR9');
    expect(sampleOf('Los Reyes del Sur')).toBe('Los Reyes');
    expect(sampleOf('Hermandad del Asfalto')).toBe('Hermandad');
    expect(sampleOf('  ')).toBe('Nombre');
  });

  it('tipografía con respaldo', () => {
    const fonts = [{ id: 'bebas', label: 'Cartel', family: 'PXO Bebas Neue' }];
    expect(fontFamily(fonts, 'bebas')).toContain("'PXO Bebas Neue'");
    expect(fontFamily(fonts, 'no-existe')).toContain("'Sora'");
  });

  it('progreso de reputación', () => {
    expect(repProgress({ reputation: 250, levelRep: 0, nextRep: 500 })).toBe(0.5);
    expect(repProgress({ reputation: 9999, levelRep: 9000, nextRep: undefined })).toBe(1);
    expect(repProgress({ reputation: 0, levelRep: 0, nextRep: 500 })).toBe(0);
  });

  it('rangos que se pueden dar: por debajo del propio, nunca el más alto ni a uno mismo', () => {
    const org = { grade: 3, grades, perms };
    expect(gradeOptions(org, member(1), 'YO').map((g) => g.level)).toEqual([0, 2]);
    expect(gradeOptions(org, member(3), 'YO')).toEqual([]);
    expect(gradeOptions(org, member(1, 'YO'), 'YO')).toEqual([]);
    expect(gradeOptions({ grade: 4, grades, perms }, member(1), 'YO').map((g) => g.level)).toEqual([0, 2, 3]);
    expect(gradeOptions({ ...org, perms: { ...perms, manage: false } }, member(1), 'YO')).toEqual([]);
    expect(canKick(org, member(2), 'YO')).toBe(true);
    expect(canKick(org, member(4), 'YO')).toBe(false);
  });

  it('formulario de fundación: dice qué falta', () => {
    const info: CreateInfo = {
      types: [{ id: 'banda', label: 'Banda' }], colors: ['#5ce1ff'], fonts: [], staff: false, cost: 25000, minFounders: 2, nameMin: 3, nameMax: 28,
      mottoMax: 60, approval: 'staff', nearby: [], blocked: false,
      requirements: [{ id: 'level', ok: true, label: 'Nivel 3', detail: '' }, { id: 'cost', ok: false, label: 'Tasa de $25000', detail: '' }],
    };
    const form = { type: 'banda', name: 'Los Reyes', color: '#5ce1ff', font: 'sora', emblem: 'LR', motto: '', founders: [2] };
    expect(createBlocker({ ...form, name: 'ab' }, info)).toMatch(/nombre/);
    expect(createBlocker({ ...form, founders: [] }, info)).toMatch(/cofundador/);
    expect(createBlocker(form, info)).toMatch(/Tasa/);
    const ready = { ...info, requirements: info.requirements.map((r) => ({ ...r, ok: true })) };
    expect(createBlocker(form, ready)).toBeNull();
    expect(createBlocker({ ...form, founders: [] }, { ...info, staff: true, minFounders: 1 })).toBeNull();
    expect(createBlocker(form, { ...ready, blocked: true })).toMatch(/banda/);
  });

  it('tiempo restante', () => {
    expect(timeLeft(100, 70)).toBe('30 s');
    expect(timeLeft(1000, 100)).toBe('15 min');
    expect(timeLeft(10, 100)).toBe('0 s');
  });
});
