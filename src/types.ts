export type MediaType = 'image' | 'video';

export interface MusicTrack {
  id: string;
  title: string;
  artist: string;
  url: string;
  duration: string;
  cover: string;
  isCustom?: boolean;
}

export type MediaItem = {
  id: string;
  uri: string;
  type: MediaType;
  thumbnailUri?: string;
  durationMs?: number;
  width?: number;
  height?: number;
};

export type ImageEditOptions = {
  rotateDegrees?: number; // 0, 90, 180, 270
  flipX?: boolean;
  flipY?: boolean;
  brightness?: number; // -1..1
  contrast?: number; // 0..2
  saturation?: number; // 0..2
  grayscale?: boolean;
  tintColor?: string;
  tintOpacity?: number;
  frame?: string;
  frameScale?: number;  // inset scale for the frame (e.g. 0.82)
  frameOffsetY?: number; // relative vertical offset inside the frame (e.g. -0.05)
  crop?: { x: number; y: number; width: number; height: number };
  effect?: string;
  arFilter?: string;
  overlays?: Array<{
    text: string;
    x: number;
    y: number;
    color: string;
    fontSize: number;
  }>;
};

export type VideoTrimOptions = ImageEditOptions & {
  startMs?: number;
  endMs?: number;
  mute?: boolean;
  isImage?: boolean;
  musicUri?: string;
};

export type FrameCaptureOptions = {
  timeMs: number;
};
