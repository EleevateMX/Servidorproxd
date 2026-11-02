// Contratos con el cliente Lua (client/main.lua y client/editor.lua). Formato de apariencia:
// el de illenium-appearance 5.7.0 (playerskins.skin), igual que shared/appearance.lua.

export type SectionId = 'identity' | 'heritage' | 'face' | 'skin' | 'hair' | 'clothes';

export interface HeadBlend {
  shapeFirst: number; shapeSecond: number; shapeThird: number;
  skinFirst: number; skinSecond: number; skinThird: number;
  shapeMix: number; skinMix: number; thirdMix: number;
}
export interface Overlay { style: number; opacity: number; color: number; secondColor: number }
export interface Component { component_id: number; drawable: number; texture: number }
export interface Prop { prop_id: number; drawable: number; texture: number }
export interface Hair { style: number; texture: number; color: number; highlight: number }

export interface Look {
  model: string;
  headBlend: HeadBlend;
  faceFeatures: Record<string, number>;
  headOverlays: Record<string, Overlay>;
  components: Component[];
  props: Prop[];
  hair: Hair;
  eyeColor: number;
  tattoos: unknown;
}

export interface Range { drawables: number; textures: number; texturesFor?: Record<string, number> }
export interface Limits {
  overlays: Record<string, number>;
  components: Record<string, Range>;
  props: Record<string, Range>;
  hairColors: number;
  makeupColors: number;
}

export interface FeatureDef { key: string; label: string; region: string }
export interface RegionDef { id: string; label: string }
export interface OverlayDef { key: string; label: string; colorType: 0 | 1 | 2; section: 'skin' | 'hair' }
export interface ClothesDef { kind: 'component' | 'prop'; id: number; label: string }
export interface Outfit { id: string; label: string; components: Component[]; props?: Prop[] }

export interface Identity {
  firstname: string; lastname: string; gender: 0 | 1; birthdate: string; nationality: string;
  nationalities?: string[]; limitNationalities?: boolean; dateMin?: string; dateMax?: string;
}

export interface EditorData {
  mode: 'create' | 'recover' | 'edit';
  title?: string;
  sections: SectionId[];
  look: Look;
  base: Look;
  identity?: Identity;
  limits: Limits;
  palettes: { hair: [number, number, number][]; makeup: [number, number, number][] };
  regions: RegionDef[];
  features: FeatureDef[];
  overlays: OverlayDef[];
  clothes: ClothesDef[];
  outfits: Record<string, Outfit[]>;
  /** Apariencia por defecto de cada sexo ("0" hombre, "1" mujer) para el cambio de sexo. */
  defaults?: Record<string, Look>;
  price?: number;
}

export interface Card {
  citizenid: string; firstname: string; lastname: string; gender: 0 | 1;
  birthdate?: string; nationality?: string; job?: string; grade?: string;
  cash: number; bank: number; level?: number; playtime?: number;
  status?: 'active' | 'dead'; location?: string;
}
export type Slot = { kind: 'character'; index: number; citizenid: string } | { kind: 'free' | 'locked'; index: number };
export interface SelectionData {
  serverName: string; characters: Card[]; slots: Slot[]; lockedLabel?: string; storeUrl?: string; enableDelete?: boolean;
}

export interface SpawnOption { id: string; kind: 'last' | 'property' | 'point' | 'apartment'; label: string; detail?: string; image?: string }
export interface SpawnView { mode: 'spawn' | 'apartment'; kicker?: string; title?: string; text?: string; confirm?: string; options: SpawnOption[] }
