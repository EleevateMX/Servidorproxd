// Nombres en español de las nacionalidades de qbx_core (data/nationalities.lua).
// El valor guardado en charinfo sigue siendo el de Qbox; solo cambia lo que se muestra.
const ES: Record<string, string> = {
  American: 'Estadounidense', Argentinean: 'Argentina', Bolivian: 'Boliviana', Brazilian: 'Brasileña',
  British: 'Británica', Canadian: 'Canadiense', Chilean: 'Chilena', Chinese: 'China', Colombian: 'Colombiana',
  'Costa Rican': 'Costarricense', Cuban: 'Cubana', Dominican: 'Dominicana', Dutch: 'Neerlandesa',
  Ecuadorean: 'Ecuatoriana', French: 'Francesa', German: 'Alemana', Greek: 'Griega', Guatemalan: 'Guatemalteca',
  Haitian: 'Haitiana', Honduran: 'Hondureña', Indian: 'India', Irish: 'Irlandesa', Italian: 'Italiana',
  Jamaican: 'Jamaicana', Japanese: 'Japonesa', Mexican: 'Mexicana', Moroccan: 'Marroquí', Nicaraguan: 'Nicaragüense',
  Panamanian: 'Panameña', Paraguayan: 'Paraguaya', Peruvian: 'Peruana', Filipino: 'Filipina', Polish: 'Polaca',
  Portuguese: 'Portuguesa', Russian: 'Rusa', Salvadoran: 'Salvadoreña', 'South Korean': 'Surcoreana',
  Spanish: 'Española', Swedish: 'Sueca', Swiss: 'Suiza', Turkish: 'Turca', Ukrainian: 'Ucraniana',
  Uruguayan: 'Uruguaya', Venezuelan: 'Venezolana', Australian: 'Australiana', Austrian: 'Austriaca',
  Belgian: 'Belga', Egyptian: 'Egipcia', Israeli: 'Israelí', Lebanese: 'Libanesa', Nigerian: 'Nigeriana',
  Norwegian: 'Noruega', Danish: 'Danesa', Finnish: 'Finlandesa', Romanian: 'Rumana', Scottish: 'Escocesa',
  Welsh: 'Galesa', 'South African': 'Sudafricana', Vietnamese: 'Vietnamita', Thai: 'Tailandesa',
};

export const nationalityLabel = (value: string): string => ES[value] ?? value;

/** Opciones ordenadas por su nombre en español. */
export function nationalityOptions(values: string[]): { value: string; label: string }[] {
  return values.map((v) => ({ value: v, label: nationalityLabel(v) })).sort((a, b) => a.label.localeCompare(b.label, 'es'));
}
