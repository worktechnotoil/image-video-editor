export type FilterCategory = 'beauty' | 'snap' | 'ar' | 'color';

export type FilterId =
  | 'none'
  // beauty
  | 'smoothSkin'
  | 'slimFace'
  | 'eyeEnhance'
  | 'lipstick'
  | 'lipstick_red'
  | 'lipstick_pink'
  | 'lipstick_coral'
  | 'lipstick_plum'
  | 'bigHead'
  // snap combo filters
  | 'snap_butterflies'
  | 'snap_neon_outline'
  | 'snap_neon_neon'
  | 'snap_sunset_cowboy'
  | 'snap_icy_dalmatian'
  | 'snap_retro_bloom'
  | 'snap_noir_kitty'
  | 'snap_evil_bw'
  | 'snap_bow_aesthetic'
  | 'snap_dark_moon'
  | 'snap_pink_hearts'
  | 'snap_day_stamp'
  | 'snap_cartoon_toon'
  | 'snap_heart_frame'
  | 'snap_city_time'
  | 'snap_pookie'
  | 'snap_panda_face'
  | 'snap_vintage_grain'
  | 'snap_spiderman'
  | 'snap_eyes_reveal'
  | 'snap_wanted_poster'
  | 'snap_pink_flower'
  | 'snap_retro_skull'
  | 'snap_fashion_overlay'
  | 'snap_talking_forest'
  | 'snap_lens_verified'
  | 'snap_creator_hud'
  // ar overlays
  | 'dogEars'
  | 'catEars'
  | 'flowerCrown'
  | 'glasses'
  | 'glasses_classic'
  | 'glasses_sun'
  | 'glasses_retro'
  | 'glasses_heart'
  | 'glasses_sport'
  // color filters
  | 'vintage'
  | 'blackWhite'
  | 'vibrant'
  | 'coolTone'
  | 'warmTone';

export interface FilterOption {
  id: FilterId;
  label: string;
  emoji: string;
  category: FilterCategory;
}

export const CATEGORIES: { id: FilterCategory; label: string; emoji: string }[] = [
  { id: 'beauty', label: 'Beauty', emoji: '💄' },
  { id: 'snap', label: 'Vibe', emoji: '🔥' },
  { id: 'ar', label: 'AR', emoji: '🐶' },
  { id: 'color', label: 'Color', emoji: '🎨' },
];

export const FILTER_CATALOG: FilterOption[] = [
  // Snap combo filters
  { id: 'snap_creator_hud', label: 'Soft Warm', emoji: '✨', category: 'snap' },
  { id: 'snap_wanted_poster', label: 'Wanted', emoji: '📜', category: 'snap' },
  { id: 'snap_lens_verified', label: 'Lens+ ID', emoji: '🪪', category: 'snap' },
  { id: 'snap_pink_flower', label: 'Plumeria', emoji: '🌸', category: 'snap' },
  { id: 'snap_butterflies', label: 'Butterflies', emoji: '🦋', category: 'snap' },
  { id: 'snap_neon_outline', label: 'Neon Sketch', emoji: '💫', category: 'snap' },
  { id: 'snap_icy_dalmatian', label: 'Snow Pup', emoji: '🐾', category: 'snap' },
  { id: 'snap_neon_neon', label: 'Neon Rush', emoji: '🌐', category: 'snap' },
  { id: 'snap_sunset_cowboy', label: 'Golden Hour', emoji: '🌅', category: 'snap' },
  { id: 'snap_retro_bloom', label: 'Bloom', emoji: '🌸', category: 'snap' },
  { id: 'snap_noir_kitty', label: 'Dark Meow', emoji: '🌙', category: 'snap' },
  { id: 'snap_evil_bw', label: 'Evil', emoji: '😈', category: 'snap' },
  { id: 'snap_bow_aesthetic', label: 'Aesthetic', emoji: '🎠', category: 'snap' },
  { id: 'snap_dark_moon', label: 'Dark Moon', emoji: '🌙', category: 'snap' },
  { id: 'snap_pink_hearts', label: 'Pink Hearts', emoji: '💗', category: 'snap' },
  { id: 'snap_day_stamp', label: 'Day', emoji: '🗓️', category: 'snap' },
  { id: 'snap_cartoon_toon', label: 'Cartoon', emoji: '🎨', category: 'snap' },
  { id: 'snap_heart_frame', label: 'Heart Frame', emoji: '💟', category: 'snap' },
  { id: 'snap_city_time', label: 'Time', emoji: '📍', category: 'snap' },
  { id: 'snap_pookie', label: 'Pookie', emoji: '🎀', category: 'snap' },
  { id: 'snap_panda_face', label: 'Panda', emoji: '🐼', category: 'snap' },
  { id: 'snap_vintage_grain', label: 'Vintage Grain', emoji: '📽️', category: 'snap' },
  { id: 'bigHead', label: 'Big Head', emoji: '🗣️', category: 'snap' },
  { id: 'snap_spiderman', label: 'Spider Mask', emoji: '🕸️', category: 'snap' },
  { id: 'snap_eyes_reveal', label: 'Eyes Reveal', emoji: '👀', category: 'snap' },
  { id: 'snap_retro_skull', label: 'Retro Skull', emoji: '💀', category: 'snap' },
  { id: 'snap_fashion_overlay', label: 'Street Style', emoji: '🧥', category: 'snap' },
  { id: 'snap_talking_forest', label: 'Talking Forest', emoji: '🌲', category: 'snap' },

  // AR overlays
  { id: 'dogEars', label: 'Dog', emoji: '🐶', category: 'ar' },
  { id: 'catEars', label: 'Cat', emoji: '🐱', category: 'ar' },
  { id: 'flowerCrown', label: 'Flowers', emoji: '🌸', category: 'ar' },
  { id: 'glasses', label: 'Glasses', emoji: '🕶️', category: 'ar' },
  // Color filters
  { id: 'vintage', label: 'Vintage', emoji: '🎞️', category: 'color' },
  { id: 'blackWhite', label: 'B&W', emoji: '⚫️', category: 'color' },
  { id: 'vibrant', label: 'Vibrant', emoji: '🌈', category: 'color' },
  { id: 'coolTone', label: 'Cool', emoji: '❄️', category: 'color' },
  { id: 'warmTone', label: 'Warm', emoji: '🔥', category: 'color' },

  // Beauty filters
  { id: 'smoothSkin', label: 'Smooth Skin', emoji: '🧴', category: 'beauty' },
  { id: 'slimFace', label: 'Slim Face', emoji: '💆', category: 'beauty' },
  { id: 'eyeEnhance', label: 'Eye Enhance', emoji: '👁️', category: 'beauty' },
  { id: 'lipstick', label: 'Lipstick', emoji: '💄', category: 'beauty' },
];

export function filtersForCategory(category: FilterCategory): FilterOption[] {
  return FILTER_CATALOG.filter((f) => f.category === category);
}
