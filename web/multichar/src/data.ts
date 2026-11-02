// Nombres para la interfaz. Ids de cabeza del creador de GTA Online (SET_PED_HEAD_BLEND_DATA)
// y orden de colores de ojos de illenium-appearance (constants.EYE_COLORS, 0..31).
export const PARENT_NAMES: Record<number, string> = {
  0: 'Benjamin', 1: 'Daniel', 2: 'Joshua', 3: 'Noah', 4: 'Andrew', 5: 'Juan', 6: 'Alex', 7: 'Isaac', 8: 'Evan',
  9: 'Ethan', 10: 'Vincent', 11: 'Angel', 12: 'Diego', 13: 'Adrian', 14: 'Gabriel', 15: 'Michael', 16: 'Santiago',
  17: 'Kevin', 18: 'Louis', 19: 'Samuel', 20: 'Anthony', 21: 'Hannah', 22: 'Audrey', 23: 'Jasmine', 24: 'Giselle',
  25: 'Amelia', 26: 'Isabella', 27: 'Zoe', 28: 'Ava', 29: 'Camila', 30: 'Violet', 31: 'Sophia', 32: 'Evelyn',
  33: 'Nicole', 34: 'Ashley', 35: 'Gracie', 36: 'Brianna', 37: 'Natalie', 38: 'Olivia', 39: 'Elizabeth',
  40: 'Charlotte', 41: 'Emma', 42: 'Claude', 43: 'Niko', 44: 'John', 45: 'Misty',
};

/** Textura del retrato en char_creator_portraits (sin verificar: si no carga, solo se ve el nombre). */
export function portraitTexture(id: number): string {
  if (id <= 20) return `male_${id}`;
  if (id <= 41) return `female_${id - 21}`;
  if (id <= 44) return `special_male_${id - 42}`;
  return 'special_female_0';
}

export const EYE_COLOR_NAMES = [
  'Verde', 'Esmeralda', 'Azul claro', 'Azul océano', 'Castaño claro', 'Castaño oscuro', 'Avellana', 'Gris oscuro',
  'Gris claro', 'Rosa', 'Amarillo', 'Morado', 'Negro total', 'Escala de grises', 'Amanecer', 'Atómico', 'Distorsión',
  'Cola', 'Explorador', 'Yin yang', 'Diana', 'Lagarto', 'Dragón', 'Extraterrestre', 'Cabra', 'Sonrisa', 'Poseído',
  'Demonio', 'Infectado', 'Alienígena', 'No muerto', 'Zombi',
];
/** Los 14 primeros son naturales; el resto, lentillas de fantasía (se marcan). */
export const NATURAL_EYES = 14;
