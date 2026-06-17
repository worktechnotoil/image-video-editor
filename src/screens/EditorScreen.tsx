import React, { useMemo, useState, useEffect, useRef } from 'react';
import {
  Alert,
  Image,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  Dimensions,
  PanResponder,
  Platform,
  TextInput,
  Modal,
  FlatList,
  ActivityIndicator,
} from 'react-native';
import { editImage, trimVideo } from '../native/MediaEditor';
import { captureFrame } from '../native/FrameGrabber';
import { saveToGallery } from '../native/MediaLibrary';
import { VideoPreview } from '../native/VideoPreview';
import Video from 'react-native-video';
import { Icon as Ionicons } from '../components/Icon';
import type { ImageEditOptions, MediaItem, MusicTrack } from '../types';


const SCREEN_WIDTH = Dimensions.get('window').width;
const SCREEN_HEIGHT = Dimensions.get('window').height;
const TIMELINE_WIDTH = SCREEN_WIDTH - 40;
const HANDLE_SIZE = 24;
const CARD_WIDTH = SCREEN_WIDTH * 0.76;
const CARD_MARGIN = 10;
const SNAP_INTERVAL = CARD_WIDTH + CARD_MARGIN * 2;

// ── Frame overlays ──────────────────────────────────────────────────────────
const FRAME_IMAGES: Record<string, any> = {
  floral_gold: require('../assets/frames/floral_gold.png'),
  film_vintage: require('../assets/frames/film_vintage.png'),
  minimal_double: require('../assets/frames/minimal_double.png'),
  polaroid_white: require('../assets/frames/polaroid_white.png'),
  watercolor_floral: require('../assets/frames/watercolor_floral.png'),
};

const FRAME_CONFIGS: Record<string, { scale: number; offsetY?: number }> = {
  floral_gold: { scale: 0.82 },
  film_vintage: { scale: 0.85 },
  minimal_double: { scale: 0.92 },
  polaroid_white: { scale: 0.72, offsetY: -0.05 },
  watercolor_floral: { scale: 0.78 },
};
const FRAME_LIST: { key: string; label: string }[] = [
  { key: 'floral_gold', label: 'Gold Floral' },
  { key: 'film_vintage', label: 'Film' },
  { key: 'minimal_double', label: 'Minimal' },
  { key: 'polaroid_white', label: 'Polaroid' },
  { key: 'watercolor_floral', label: 'Watercolor' },
];
const DUMMY_MUSIC_LIST: MusicTrack[] = [
  {
    id: '1',
    title: 'Sunny Days',
    artist: 'Lofi Dreamer',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    duration: '6:12',
    cover: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150&auto=format&fit=crop&q=60',
  },
  {
    id: '2',
    title: 'Urban Groove',
    artist: 'Beatmaster',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    duration: '7:05',
    cover: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=150&auto=format&fit=crop&q=60',
  },
  {
    id: '3',
    title: 'Calm Waters',
    artist: 'Ambient Sound',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    duration: '5:44',
    cover: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=150&auto=format&fit=crop&q=60',
  },
  {
    id: '4',
    title: 'Epic Journey',
    artist: 'Cinematic Orchestra',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    duration: '5:02',
    cover: 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=150&auto=format&fit=crop&q=60',
  },
  {
    id: '5',
    title: 'Original Audio',
    artist: 'vivek_saaraswat',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    duration: '0:20',
    cover: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=150&auto=format&fit=crop&q=60',
  },
  {
    id: '6',
    title: 'Baapu Jaisa Insan',
    artist: 'Nitin Sharma, Mr Dutt',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
    duration: '0:35',
    cover: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=150&auto=format&fit=crop&q=60',
  },
  {
    id: '7',
    title: 'Poonam Kero Chand',
    artist: 'Raju Mewadi, Twinkle Vaishn',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
    duration: '0:45',
    cover: 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=150&auto=format&fit=crop&q=60',
  },
  {
    id: '8',
    title: 'Kesariya Tera',
    artist: 'Arijit Singh',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    duration: '0:30',
    cover: 'https://images.unsplash.com/photo-1487180142328-0c4e37023af5?w=150&auto=format&fit=crop&q=60',
  },
  {
    id: '9',
    title: 'Calm Down',
    artist: 'Rema, Selena Gomez',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
    duration: '0:25',
    cover: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=150&auto=format&fit=crop&q=60',
  },
  {
    id: '10',
    title: 'Shape of You',
    artist: 'Ed Sheeran',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
    duration: '0:40',
    cover: 'https://images.unsplash.com/photo-1453090927415-5f45085b65c0?w=150&auto=format&fit=crop&q=60',
  },
  {
    id: 'c1',
    title: 'Custom Beat 01',
    artist: 'My Studio',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3',
    duration: '4:15',
    cover: 'https://images.unsplash.com/photo-1484755560693-a4074577af3a?w=150&auto=format&fit=crop&q=60',
    isCustom: true,
  },
  {
    id: 'c2',
    title: 'Acoustic Guitar Loop',
    artist: 'My Audio',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
    duration: '3:45',
    cover: 'https://images.unsplash.com/photo-1510915228340-29c85a43dcfe?w=150&auto=format&fit=crop&q=60',
    isCustom: true,
  },
  {
    id: 'c3',
    title: 'Vibrant Synthwave',
    artist: 'Draft Beats',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3',
    duration: '5:12',
    cover: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150&auto=format&fit=crop&q=60',
    isCustom: true,
  },
  {
    id: 'c4',
    title: 'Original Mix 2026',
    artist: 'Studio Session',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3',
    duration: '2:58',
    cover: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=150&auto=format&fit=crop&q=60',
    isCustom: true,
  }
];
interface EditorStateSnapshot {
  imageOptions: ImageEditOptions;
  activeFilter: string;
  trimStart: number;
  trimEnd: number;
  cropRatio: number | 'custom' | null;
  cropOffset: { x: number; y: number };
  zoomScale: number;
  overlays: Array<{ id: string; text: string; x: number; y: number; color: string; fontSize: number }>;
  stickers: Array<{ id: string; emoji: string; x: number; y: number; size: number }>;
  activeEffect: string;
  captions: Array<{ id: string; text: string; style: string; x: number; y: number }>;
}

export function EditorScreen({
  items,
  initialIndex = 0,
  onBack,
  onSaved,
  onOpenCrop,
  musicList,
  maxVideoDurationMs,
}: {
  items: MediaItem[];
  initialIndex?: number;
  onBack: () => void;
  onSaved: (updatedItems: MediaItem[]) => void;
  onOpenCrop: (item: MediaItem) => void;
  musicList?: MusicTrack[];
  maxVideoDurationMs?: number;
}) {
  const [activeIndex, setActiveIndex] = useState(initialIndex);
  const currentItem = items[activeIndex] || items[0];
  const item = currentItem; // Aliasing to 'item' for ease of compatibility

  useEffect(() => {
    setActiveIndex(initialIndex);
  }, [initialIndex]);

  const [activeFilter, setActiveFilter] = useState('none');
  const [imageOptions, setImageOptions] = useState<ImageEditOptions>({
    rotateDegrees: 0,
    flipX: false,
    flipY: false,
    brightness: 0,
    contrast: 1,
    saturation: 1,
    grayscale: false,
  });
  const [panel, setPanel] = useState<'filter' | 'edit' | 'trim' | 'transform' | 'frame' | 'text' | 'ar' | 'music' | 'sticker' | 'effects' | 'caption' | 'addclip'>(item.type === 'video' ? 'trim' : 'filter');
  const [trimStart, setTrimStart] = useState(0);
  const [trimEnd, setTrimEnd] = useState(() => {
    const end = item.durationMs || 10000;
    return maxVideoDurationMs ? Math.min(end, maxVideoDurationMs) : end;
  });

  useEffect(() => {
    setTrimStart(0);
    const end = item.durationMs || maxVideoDurationMs || 10000;
    setTrimEnd(maxVideoDurationMs ? Math.min(end, maxVideoDurationMs) : end);
    setThumbnails([]);
    if (item.type === 'video' && maxVideoDurationMs && end > maxVideoDurationMs) {
      setPanel('trim');
    }
  }, [item.id, item.durationMs, maxVideoDurationMs]);

  const [editsHistory, setEditsHistory] = useState<Record<string, any>>({});
  const editsHistoryRef = useRef<Record<string, any>>({});
  const [dimensionsMap, setDimensionsMap] = useState<Record<string, { width: number; height: number }>>({});
  const [uiCanvasWidths, setUiCanvasWidths] = useState<Record<string, number>>({});
  const flatListRef = useRef<FlatList>(null);

  useEffect(() => {
    if (initialIndex > 0 && flatListRef.current) {
      setTimeout(() => {
        flatListRef.current?.scrollToIndex({ index: initialIndex, animated: false });
      }, 150);
    }
  }, [initialIndex]);

  // Auto-play video whenever active card changes in multi-select mode
  useEffect(() => {
    setVideoPaused(false);
  }, [activeIndex]);

  const saveEditsForIndex = (index: number) => {
    const targetItem = items[index];
    if (!targetItem) return;
    const currentEdits = {
      activeFilter,
      imageOptions,
      trimStart,
      trimEnd,
      overlays,
      cropRatio,
      cropOffset,
      zoomScale,
      straightenAngle,
      isMuted,
    };
    editsHistoryRef.current[targetItem.id] = currentEdits;
    setEditsHistory((prev) => ({
      ...prev,
      [targetItem.id]: currentEdits,
    }));
  };

  const loadEditsForIndex = (index: number) => {
    setUndoStack([]);
    setRedoStack([]);
    const targetItem = items[index];
    if (!targetItem) return;
    const saved = editsHistoryRef.current[targetItem.id];
    if (saved) {
      setActiveFilter(saved.activeFilter);
      setImageOptions(saved.imageOptions);
      setTrimStart(saved.trimStart);
      setTrimEnd(saved.trimEnd);
      setOverlays(saved.overlays);
      setCropRatio(saved.cropRatio);
      setCropOffset(saved.cropOffset);
      setZoomScale(saved.zoomScale);
      setStraightenAngle(saved.straightenAngle);
      setIsMuted(selectedMusic ? true : saved.isMuted);
    } else {
      setActiveFilter('none');
      setImageOptions({
        rotateDegrees: 0,
        flipX: false,
        flipY: false,
        brightness: 0,
        contrast: 1,
        saturation: 1,
        grayscale: false,
      });
      setTrimStart(0);
      const end = targetItem.durationMs || 10000;
      setTrimEnd(maxVideoDurationMs ? Math.min(end, maxVideoDurationMs) : end);
      setOverlays([]);
      setCropRatio(null);
      setCropOffset({ x: 0, y: 0 });
      setZoomScale(1);
      setStraightenAngle(0);
      setIsMuted(selectedMusic ? true : false);
    }
    
    // Force trim panel if video is too long
    if (targetItem.type === 'video' && maxVideoDurationMs && targetItem.durationMs && targetItem.durationMs > maxVideoDurationMs) {
      setPanel('trim');
    } else if (!saved) {
      setPanel(targetItem.type === 'video' ? 'trim' : 'filter');
    }
  };

  const handleScrollEnd = (e: any) => {
    const offsetX = e.nativeEvent.contentOffset.x;
    const newIndex = Math.round(offsetX / SNAP_INTERVAL);
    if (newIndex >= 0 && newIndex < items.length && newIndex !== activeIndex) {
      saveEditsForIndex(activeIndex);
      setActiveIndex(newIndex);
      loadEditsForIndex(newIndex);
    }
  };

  const buildOptionsForItem = (targetItem: MediaItem, edits: any) => {
    const targetDim = dimensionsMap[targetItem.id] || { width: 1080, height: 1080 };
    let imgW = targetDim.width;
    let imgH = targetDim.height;
    if ((edits.imageOptions.rotateDegrees || 0) % 180 !== 0) {
      imgW = targetDim.height;
      imgH = targetDim.width;
    }

    const scale = maxPan.scale;
    const cropWidth = maxPan.boxW / scale;
    const cropHeight = maxPan.boxH / scale;

    const centerX = (imgW - cropWidth) / 2;
    const centerY = (imgH - cropHeight) / 2;

    let nx = centerX - (edits.cropOffset.x / scale);
    let ny = centerY - (edits.cropOffset.y / scale);

    nx = Math.max(0, Math.min(nx, imgW - cropWidth));
    ny = Math.max(0, Math.min(ny, imgH - cropHeight));

    const finalCrop = {
      x: Math.round(nx),
      y: Math.round(ny),
      width: Math.round(cropWidth),
      height: Math.round(cropHeight),
    };

    const frameConfig = (FRAME_CONFIGS as any)[edits.imageOptions.frame || ''] || { scale: 1, offsetY: 0 };
    const actualUiWidth = uiCanvasWidths[targetItem.id] || CARD_WIDTH;
    const renderScale = cropWidth / actualUiWidth;

    const hasCrop = edits.cropRatio !== null || edits.zoomScale > 1 || edits.cropOffset.x !== 0 || edits.cropOffset.y !== 0;

    return {
      ...edits.imageOptions,
      rotateDegrees: (edits.imageOptions.rotateDegrees || 0) + edits.straightenAngle,
      ...(hasCrop ? { crop: finalCrop } : {}),
      imageAspectRatio: targetDim.width / (targetDim.height || 1),
      frameScale: edits.imageOptions.frame ? frameConfig.scale : 1,
      frameOffsetY: edits.imageOptions.frame ? (frameConfig.offsetY || 0) : 0,
      overlays: edits.overlays.map((o: any) => ({
        text: o.text,
        x: (o.x + 12) * renderScale,
        y: (o.y + 12) * renderScale,
        color: o.color,
        fontSize: o.fontSize * renderScale,
      })),
      frameUri: edits.imageOptions.frame && FRAME_IMAGES[edits.imageOptions.frame] 
        ? Image.resolveAssetSource(FRAME_IMAGES[edits.imageOptions.frame]).uri 
        : undefined,
    };
  };

  const [saving, setSaving] = useState(false);
  const [videoPaused, setVideoPaused] = useState(false);
  const resolvedMusicList = musicList || [];

  const [selectedMusic, setSelectedMusic] = useState<MusicTrack | null>(null);
  const [musicPaused, setMusicPaused] = useState(false);
  const [showMusicModal, setShowMusicModal] = useState(false);
  const [musicSearchQuery, setMusicSearchQuery] = useState('');
  const [activeMusicTab, setActiveMusicTab] = useState<'for_you' | 'trending' | 'saved' | 'original' | 'custom'>('trending');

  const filteredMusicList = useMemo(() => {
    let list = resolvedMusicList;
    const hasCustomTracks = resolvedMusicList.some(track => track.isCustom);

    if (musicList) {
      // If custom musicList is passed as a prop, keep it clean
      if (activeMusicTab === 'trending') {
        list = hasCustomTracks ? resolvedMusicList.filter(track => !track.isCustom) : resolvedMusicList;
      } else if (activeMusicTab === 'for_you') {
        list = hasCustomTracks ? resolvedMusicList.filter(track => !track.isCustom) : resolvedMusicList;
      } else if (activeMusicTab === 'saved') {
        const nonCustom = hasCustomTracks ? resolvedMusicList.filter(track => !track.isCustom) : resolvedMusicList;
        list = nonCustom.slice(0, Math.min(nonCustom.length, 3));
      } else if (activeMusicTab === 'original') {
        list = resolvedMusicList.filter(track => track.title.toLowerCase().includes('original') || track.artist.toLowerCase().includes('original'));
      } else if (activeMusicTab === 'custom') {
        list = hasCustomTracks ? resolvedMusicList.filter(track => track.isCustom) : resolvedMusicList;
      }
    } else {
      // Fallback to DUMMY_MUSIC_LIST with mock slicing
      if (activeMusicTab === 'trending') {
        const nonCustom = resolvedMusicList.filter(track => !track.isCustom);
        list = nonCustom.slice(4, 10);
      } else if (activeMusicTab === 'for_you') {
        const nonCustom = resolvedMusicList.filter(track => !track.isCustom);
        list = nonCustom.slice(0, 4);
      } else if (activeMusicTab === 'saved') {
        const nonCustom = resolvedMusicList.filter(track => !track.isCustom);
        list = [nonCustom[1], nonCustom[3], nonCustom[5]];
      } else if (activeMusicTab === 'original') {
        list = resolvedMusicList.filter(track => track.title.toLowerCase().includes('original') || track.artist.toLowerCase().includes('original') || track.id === '5');
      } else if (activeMusicTab === 'custom') {
        list = resolvedMusicList.filter(track => track.isCustom);
      }
    }

    if (musicSearchQuery.trim().length > 0) {
      const q = musicSearchQuery.toLowerCase();
      list = list.filter(
        (track) =>
          track.title.toLowerCase().includes(q) ||
          track.artist.toLowerCase().includes(q)
      );
    }
    return list;
  }, [activeMusicTab, musicSearchQuery, resolvedMusicList, musicList]);

  const [thumbnails, setThumbnails] = useState<string[]>([]);
  const [isMuted, setIsMuted] = useState(false);
  const [isEditingVideo, setIsEditingVideo] = useState(false);
  const [currentTimeMs, setCurrentTimeMs] = useState(0);
  const [seekToMs, setSeekToMs] = useState<number>(-1);
  const [scrollEnabled, setScrollEnabled] = useState(true);

  const isUserScrolling = useRef(false);
  const isDraggingHandle = useRef(false);
  const timelineScrollRef = useRef<ScrollView>(null);

  const isMomentumScrolling = useRef(false);
  const lastSeekTime = useRef(0);
  const pendingSeek = useRef<number | null>(null);
  const seekTimeout = useRef<any>(null);

  const throttledSeek = (time: number) => {
    const now = Date.now();
    if (now - lastSeekTime.current > 65) {
      lastSeekTime.current = now;
      setSeekToMs(time);
      if (seekTimeout.current) {
        clearTimeout(seekTimeout.current);
        seekTimeout.current = null;
      }
    } else {
      pendingSeek.current = time;
      if (!seekTimeout.current) {
        seekTimeout.current = setTimeout(() => {
          if (pendingSeek.current !== null) {
            setSeekToMs(pendingSeek.current);
            lastSeekTime.current = Date.now();
            pendingSeek.current = null;
          }
          seekTimeout.current = null;
        }, 65);
      }
    }
  };

  const [cropRatio, setCropRatio] = useState<number | 'custom' | null>(null);
  const [showQuickRatioMenu, setShowQuickRatioMenu] = useState(false);
  const [dimensions, setDimensions] = useState({ width: 0, height: 0 });
  const [crop, setCrop] = useState<{ x: number; y: number; width: number; height: number } | null>(null);
  const [transformBackup, setTransformBackup] = useState<any>(null);
  const [overlays, setOverlays] = useState<Array<{ id: string; text: string; x: number; y: number; color: string; fontSize: number }>>([]);
  const [editingTextId, setEditingTextId] = useState<string | null>(null);
  const [newText, setNewText] = useState('');
  const isNewOverlay = React.useRef(false); // track if overlay was just created (not yet saved)
  const originalOverlayBackup = React.useRef<{ id: string; text: string; x: number; y: number; color: string; fontSize: number } | null>(null);
  const [activeDraggingId, setActiveDraggingId] = useState<string | null>(null);
  const [isOverTrash, setIsOverTrash] = useState(false);

  // ── Stickers ────────────────────────────────────────────────────────────────
  const STICKER_LIST = [
    '😂', '❤️', '🔥', '✨', '💯', '👑', '🎉', '🌈', '🎶', '💫',
    '🙌', '😍', '🤩', '😎', '🥳', '🌸', '🦋', '⚡', '🌙', '💎',
    '🍕', '🎸', '🎬', '📸', '🎯', '🌺', '🦄', '🐉', '🎭', '🪩',
  ];
  const [stickers, setStickers] = useState<Array<{ id: string; emoji: string; x: number; y: number; size: number }>>([]);
  const addSticker = (emoji: string) => {
    pushToHistory();
    setStickers(prev => [...prev, { id: Date.now().toString(), emoji, x: 80, y: 80, size: 48 }]);
  };
  const removeSticker = (id: string) => {
    pushToHistory();
    setStickers(prev => prev.filter(s => s.id !== id));
  };

  // ── Effects ─────────────────────────────────────────────────────────────────
  const EFFECTS_LIST = [
    { id: 'none', label: 'None', icon: '⬜' },
    { id: 'glitch', label: 'Glitch', icon: '📡' },
    { id: 'blur', label: 'Blur', icon: '💨' },
    { id: 'vignette', label: 'Vignette', icon: '🌑' },
    { id: 'grain', label: 'Grain', icon: '📺' },
    { id: 'retro', label: 'Retro', icon: '📷' },
    { id: 'neon', label: 'Neon', icon: '💡' },
    { id: 'fade', label: 'Fade', icon: '🌫️' },
  ];
  const [activeEffect, setActiveEffect] = useState('none');

  // ── Captions ─────────────────────────────────────────────────────────────────
  const CAPTION_STYLES = [
    { id: 'classic', label: 'Classic', bg: 'rgba(0,0,0,0.6)', color: '#fff', fontWeight: '400' as const },
    { id: 'bold', label: 'Bold', bg: 'rgba(0,0,0,0.8)', color: '#FFD700', fontWeight: '900' as const },
    { id: 'neon', label: 'Neon', bg: 'rgba(0,0,80,0.7)', color: '#00FFFF', fontWeight: '700' as const },
    { id: 'minimal', label: 'Minimal', bg: 'transparent', color: '#fff', fontWeight: '300' as const },
    { id: 'warm', label: 'Warm', bg: 'rgba(180,80,0,0.7)', color: '#FFF8DC', fontWeight: '600' as const },
  ];
  const [captions, setCaptions] = useState<Array<{ id: string; text: string; style: string; x: number; y: number }>>([]);
  const [captionInput, setCaptionInput] = useState('');
  const [captionStyle, setCaptionStyle] = useState('classic');
  const addCaption = () => {
    if (!captionInput.trim()) return;
    pushToHistory();
    setCaptions(prev => [...prev, { id: Date.now().toString(), text: captionInput.trim(), style: captionStyle, x: 60, y: 200 }]);
    setCaptionInput('');
  };
  const removeCaption = (id: string) => {
    pushToHistory();
    setCaptions(prev => prev.filter(c => c.id !== id));
  };

  const addTextOverlay = () => {
    pushToHistory();
    const id = Date.now().toString();
    const newItem = {
      id,
      text: '', // start empty so placeholder shows
      x: 50,
      y: 50,
      color: '#FFFFFF',
      fontSize: 24,
    };
    // Add immediately so live typing & coloring works!
    setOverlays(prev => [...prev, newItem]);
    setEditingTextId(id);
    setNewText('');
    isNewOverlay.current = true;
    originalOverlayBackup.current = null;
    setPanel('text');
  };

  const updateTextOverlay = (id: string, patch: any) => {
    setOverlays(prev => prev.map(o => o.id === id ? { ...o, ...patch } : o));
  };

  const removeTextOverlay = (id: string) => {
    pushToHistory();
    setOverlays(prev => prev.filter(o => o.id !== id));
    if (editingTextId === id) setEditingTextId(null);
  };

  const handleOpenTransform = () => {
    // Open the dedicated CropScreen
    onOpenCrop(item);
  };

  const handleCancelTransform = () => {
    if (transformBackup) {
      setImageOptions((prev) => ({
        ...prev,
        rotateDegrees: transformBackup.rotateDegrees,
        flipX: transformBackup.flipX,
        flipY: transformBackup.flipY,
      }));
      setCropRatio(transformBackup.cropRatio);
      setCrop(transformBackup.crop);
      setZoomScale(transformBackup.zoomScale ?? 1);
      setCropOffset(transformBackup.cropOffset ?? { x: 0, y: 0 });
      setStraightenAngle(transformBackup.straightenAngle ?? 0);
      setCropResizeScale(transformBackup.cropResizeScale ?? 1);
    }
    setPanel('filter');
  };

  useEffect(() => {
    let cancelled = false;

    if (item.width && item.height) {
      setDimensions({ width: item.width, height: item.height });
      setDimensionsMap((prev) => ({ ...prev, [item.id]: { width: item.width || 0, height: item.height || 0 } }));
      return () => {
        cancelled = true;
      };
    }

    if (item.type === 'image') {
      Image.getSize(
        item.uri,
        (width, height) => {
          if (!cancelled) {
            setDimensions({ width, height });
            setDimensionsMap((prev) => ({ ...prev, [item.id]: { width, height } }));
          }
        },
        (err) => {
          console.warn('Failed to get image size, using fallback', err);
          if (!cancelled) {
            setDimensions({ width: 1080, height: 1080 });
            setDimensionsMap((prev) => ({ ...prev, [item.id]: { width: 1080, height: 1080 } }));
          }
        }
      );
      return () => {
        cancelled = true;
      };
    }

    // For videos, resolve accurate dimensions from a captured frame.
    // This keeps exported crop/portrait/square changes aligned with preview.
    (async () => {
      try {
        const frameUri = await captureFrame(item.uri, { timeMs: 0 });
        Image.getSize(
          frameUri,
          (width, height) => {
            if (!cancelled) {
              setDimensions({ width, height });
              setDimensionsMap((prev) => ({ ...prev, [item.id]: { width, height } }));
            }
          },
          () => {
            if (!cancelled) {
              setDimensions({ width: 1080, height: 1920 });
              setDimensionsMap((prev) => ({ ...prev, [item.id]: { width: 1080, height: 1920 } }));
            }
          }
        );
      } catch {
        if (!cancelled) {
          setDimensions({ width: 1080, height: 1920 });
          setDimensionsMap((prev) => ({ ...prev, [item.id]: { width: 1080, height: 1920 } }));
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [item.uri, item.width, item.height, item.type, item.id]);

  const [cropOffset, setCropOffset] = useState({ x: 0, y: 0 });
  const [zoomScale, setZoomScale] = useState(1);
  const [straightenAngle, setStraightenAngle] = useState(0);
  const [cropResizeScale, setCropResizeScale] = useState(1);
  const [cropResizeScaleX, setCropResizeScaleX] = useState(1);
  const [cropResizeScaleY, setCropResizeScaleY] = useState(1);
  const panStart = useRef({ x: 0, y: 0 });
  const lastTouchDist = useRef<number | null>(null);
  const resizeStartScale = useRef(1);
  const resizeStartScaleX = useRef(1);
  const resizeStartScaleY = useRef(1);
  const cropRatioRef = useRef<number | 'custom' | null>(cropRatio);
  const panelRef = useRef(panel);
  const itemTypeRef = useRef(item.type);
  const cropOffsetRef = useRef(cropOffset);
  const zoomScaleRef = useRef(zoomScale);

  const [undoStack, setUndoStack] = useState<EditorStateSnapshot[]>([]);
  const [redoStack, setRedoStack] = useState<EditorStateSnapshot[]>([]);

  const pushToHistory = () => {
    const snapshot: EditorStateSnapshot = {
      imageOptions: { ...imageOptions },
      activeFilter,
      trimStart,
      trimEnd,
      cropRatio,
      cropOffset: { ...cropOffset },
      zoomScale,
      overlays: overlays.map(o => ({ ...o })),
      stickers: stickers.map(s => ({ ...s })),
      activeEffect,
      captions: captions.map(c => ({ ...c })),
    };
    setUndoStack(prev => [...prev, snapshot]);
    setRedoStack([]); // Clear redo stack on new action
  };

  const applySnapshot = (snapshot: EditorStateSnapshot) => {
    setImageOptions(snapshot.imageOptions);
    setActiveFilter(snapshot.activeFilter);
    setTrimStart(snapshot.trimStart);
    setTrimEnd(snapshot.trimEnd);
    setCropRatio(snapshot.cropRatio);
    setCropOffset(snapshot.cropOffset);
    setZoomScale(snapshot.zoomScale);
    setOverlays(snapshot.overlays);
    setStickers(snapshot.stickers);
    setActiveEffect(snapshot.activeEffect);
    setCaptions(snapshot.captions);

    // If trim changes, seek to trimStart
    if (snapshot.trimStart !== trimStart) {
      throttledSeek(snapshot.trimStart);
    }
  };

  const handleUndo = () => {
    if (undoStack.length === 0) return;

    const currentSnapshot: EditorStateSnapshot = {
      imageOptions: { ...imageOptions },
      activeFilter,
      trimStart,
      trimEnd,
      cropRatio,
      cropOffset: { ...cropOffset },
      zoomScale,
      overlays: overlays.map(o => ({ ...o })),
      stickers: stickers.map(s => ({ ...s })),
      activeEffect,
      captions: captions.map(c => ({ ...c })),
    };

    const previousSnapshot = undoStack[undoStack.length - 1];
    setUndoStack(prev => prev.slice(0, prev.length - 1));
    setRedoStack(prev => [...prev, currentSnapshot]);

    applySnapshot(previousSnapshot);
  };

  const handleRedo = () => {
    if (redoStack.length === 0) return;

    const currentSnapshot: EditorStateSnapshot = {
      imageOptions: { ...imageOptions },
      activeFilter,
      trimStart,
      trimEnd,
      cropRatio,
      cropOffset: { ...cropOffset },
      zoomScale,
      overlays: overlays.map(o => ({ ...o })),
      stickers: stickers.map(s => ({ ...s })),
      activeEffect,
      captions: captions.map(c => ({ ...c })),
    };

    const nextSnapshot = redoStack[redoStack.length - 1];
    setRedoStack(prev => prev.slice(0, prev.length - 1));
    setUndoStack(prev => [...prev, currentSnapshot]);

    applySnapshot(nextSnapshot);
  };

  useEffect(() => {
    cropRatioRef.current = cropRatio;
    panelRef.current = panel;
    itemTypeRef.current = item.type;
    cropOffsetRef.current = cropOffset;
    zoomScaleRef.current = zoomScale;
  }, [cropRatio, panel, item.type, cropOffset, zoomScale]);

  const handleStraighten = (gesture: any) => {
    // Simple straighten logic: 1 pixel = 0.2 degrees
    const delta = gesture.dx * 0.2;
    setStraightenAngle(prev => Math.max(-45, Math.min(45, prev + delta)));
  };

  const straightenPan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onPanResponderMove: (_, gesture) => {
        const delta = gesture.dx * 0.1;
        setStraightenAngle(prev => Math.max(-45, Math.min(45, prev + delta)));
      },
    })
  ).current;

  const createCornerPan = (corner: 'TL' | 'TR' | 'BL' | 'BR') => {
    return PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onPanResponderGrant: () => {
        resizeStartScale.current = cropResizeScale;
        resizeStartScaleX.current = cropResizeScaleX;
        resizeStartScaleY.current = cropResizeScaleY;
      },
      onPanResponderMove: (_, gesture) => {
        if (cropRatioRef.current === 'custom') {
          const sensitivity = 0.005;
          let xDelta = 0;
          let yDelta = 0;
          if (corner === 'TL') {
            xDelta = -gesture.dx;
            yDelta = -gesture.dy;
          } else if (corner === 'TR') {
            xDelta = gesture.dx;
            yDelta = -gesture.dy;
          } else if (corner === 'BL') {
            xDelta = -gesture.dx;
            yDelta = gesture.dy;
          } else {
            xDelta = gesture.dx;
            yDelta = gesture.dy;
          }
          const newScaleX = Math.max(0.2, Math.min(1.0, resizeStartScaleX.current + xDelta * sensitivity));
          const newScaleY = Math.max(0.2, Math.min(1.0, resizeStartScaleY.current + yDelta * sensitivity));
          setCropResizeScaleX(newScaleX);
          setCropResizeScaleY(newScaleY);
          return;
        }

        let delta = 0;
        const sensitivity = 0.005;
        if (corner === 'TL') delta = -gesture.dx - gesture.dy;
        else if (corner === 'TR') delta = gesture.dx - gesture.dy;
        else if (corner === 'BL') delta = -gesture.dx + gesture.dy;
        else if (corner === 'BR') delta = gesture.dx + gesture.dy;

        const newScale = Math.max(0.3, Math.min(1.0, resizeStartScale.current + delta * sensitivity));
        setCropResizeScale(newScale);
      }
    });
  };

  const cornerTL = useRef(createCornerPan('TL')).current;
  const cornerTR = useRef(createCornerPan('TR')).current;
  const cornerBL = useRef(createCornerPan('BL')).current;
  const cornerBR = useRef(createCornerPan('BR')).current;

  const createTextPan = (id: string) => {
    let startX = 0;
    let startY = 0;
    let pressStartTime = 0;
    let hasMoved = false;
    let longPressTimeout: any = null;

    return PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: () => {
        pressStartTime = Date.now();
        hasMoved = false;
        setActiveDraggingId(id);
        setIsOverTrash(false);
        
        setOverlays(prev => {
          const item = prev.find(o => o.id === id);
          if (item) {
            startX = item.x;
            startY = item.y;
          }
          return prev;
        });

        // Setup long press timer (600ms)
        if (longPressTimeout) clearTimeout(longPressTimeout);
        longPressTimeout = setTimeout(() => {
          if (!hasMoved) {
            removeTextOverlay(id);
          }
        }, 600);
      },
      onPanResponderMove: (_, gesture) => {
        if (Math.abs(gesture.dx) > 4 || Math.abs(gesture.dy) > 4) {
          hasMoved = true;
          if (longPressTimeout) {
            clearTimeout(longPressTimeout);
            longPressTimeout = null;
          }
        }
        
        const newX = startX + gesture.dx;
        const newY = startY + gesture.dy;

        // Trash zone: bottom 140px of screen, center horizontal
        const isNearTrash = gesture.moveY > SCREEN_HEIGHT - 140 && Math.abs(gesture.moveX - (SCREEN_WIDTH / 2)) < 90;
        setIsOverTrash(isNearTrash);

        setOverlays(prev => prev.map(o => o.id === id ? {
          ...o,
          x: newX,
          y: newY
        } : o));
      },
      onPanResponderRelease: (_, gesture) => {
        if (longPressTimeout) {
          clearTimeout(longPressTimeout);
          longPressTimeout = null;
        }

        // Check if released over trash zone using final touch screen coordinates
        const releasedOverTrash = gesture.moveY > SCREEN_HEIGHT - 140 && Math.abs(gesture.moveX - (SCREEN_WIDTH / 2)) < 90;

        // Reset dragging states
        setActiveDraggingId(null);
        setIsOverTrash(false);

        if (releasedOverTrash) {
          setTimeout(() => {
            removeTextOverlay(id);
          }, 50);
          return;
        }

        const pressDuration = Date.now() - pressStartTime;
        if (!hasMoved && pressDuration < 250) {
          pushToHistory();
          setOverlays(prev => {
            const found = prev.find(o => o.id === id);
            if (found) {
              originalOverlayBackup.current = { ...found };
              isNewOverlay.current = false;
              setEditingTextId(id);
              setNewText(found.text);
              setPanel('text');
            }
            return prev;
          });
        }
      },
      onPanResponderTerminate: () => {
        if (longPressTimeout) {
          clearTimeout(longPressTimeout);
          longPressTimeout = null;
        }
        setActiveDraggingId(null);
        setIsOverTrash(false);
      }
    });
  };

  const textResponders = useRef<Record<string, any>>({});

  const getTextResponder = (id: string) => {
    if (!textResponders.current[id]) {
      textResponders.current[id] = createTextPan(id);
    }
    return textResponders.current[id];
  };

  const containerHeight = showMusicModal ? (SCREEN_WIDTH * 0.72) : (SCREEN_WIDTH * 1.25);

  const maxPan = useMemo(() => {
    // If no cropRatio, we still want to allow panning/zooming if zoomScale > 1
    let imgW = dimensions.width || item.width || 1080;
    let imgH = dimensions.height || item.height || 1920;
    if ((imageOptions.rotateDegrees || 0) % 180 !== 0) {
      const temp = imgW;
      imgW = imgH;
      imgH = temp;
    }
    const actualRatio = typeof cropRatio === 'number' ? cropRatio : imgW / (imgH || 1);

    const baseH = actualRatio <= 1 ? containerHeight - 24 : (SCREEN_WIDTH - 24) / actualRatio;
    const baseW = actualRatio > 1 ? SCREEN_WIDTH - 24 : baseH * actualRatio;

    const boxW = baseW * (cropRatio === 'custom' ? cropResizeScaleX : cropResizeScale);
    const boxH = baseH * (cropRatio === 'custom' ? cropResizeScaleY : cropResizeScale);

    const minScale = Math.max(boxW / (imgW || 1), boxH / (imgH || 1));
    const totalScale = minScale * zoomScale;

    return {
      dx: Math.max(0, ((imgW * totalScale) - boxW) / 2),
      dy: Math.max(0, ((imgH * totalScale) - boxH) / 2),
      scale: totalScale,
      boxW,
      boxH
    };
  }, [cropRatio, dimensions, item, imageOptions.rotateDegrees, zoomScale, cropResizeScale, cropResizeScaleX, cropResizeScaleY, showMusicModal, containerHeight]);

  const maxPanRef = useRef(maxPan);
  useEffect(() => {
    maxPanRef.current = maxPan;
  }, [maxPan]);

  const cropPan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => panelRef.current === 'transform',
      onMoveShouldSetPanResponder: () => panelRef.current === 'transform',
      onPanResponderGrant: (evt) => {
        pushToHistory();
        panStart.current = { x: cropOffsetRef.current.x, y: cropOffsetRef.current.y };
        if (evt.nativeEvent.touches.length === 2) {
          const t1 = evt.nativeEvent.touches[0];
          const t2 = evt.nativeEvent.touches[1];
          lastTouchDist.current = Math.sqrt(
            Math.pow(t2.pageX - t1.pageX, 2) + Math.pow(t2.pageY - t1.pageY, 2)
          );
        } else {
          lastTouchDist.current = null;
        }
      },
      onPanResponderMove: (evt, gesture) => {
        if (evt.nativeEvent.touches.length === 2 && lastTouchDist.current !== null) {
          // Handle Pinch-to-Zoom
          const t1 = evt.nativeEvent.touches[0];
          const t2 = evt.nativeEvent.touches[1];
          const dist = Math.sqrt(
            Math.pow(t2.pageX - t1.pageX, 2) + Math.pow(t2.pageY - t1.pageY, 2)
          );
          const delta = dist / lastTouchDist.current;
          setZoomScale(prev => Math.max(1, Math.min(prev * delta, 5)));
          lastTouchDist.current = dist;
        } else if (evt.nativeEvent.touches.length === 1) {
          // Handle Pan
          const nx = Math.max(-maxPanRef.current.dx, Math.min(panStart.current.x + gesture.dx, maxPanRef.current.dx));
          const ny = Math.max(-maxPanRef.current.dy, Math.min(panStart.current.y + gesture.dy, maxPanRef.current.dy));
          setCropOffset({ x: nx, y: ny });
        }
      },
      onPanResponderRelease: () => {
        lastTouchDist.current = null;
      }
    })
  ).current;

  const activeOptions = useMemo(() => {
    let imgW = dimensions.width || item.width || 1080;
    let imgH = dimensions.height || item.height || 1920;
    if ((imageOptions.rotateDegrees || 0) % 180 !== 0) {
      const temp = imgW;
      imgW = imgH;
      imgH = temp;
    }

    const actualRatio = typeof cropRatio === 'number' ? cropRatio : imgW / (imgH || 1);
    const scale = maxPan.scale;
    const cropWidth = maxPan.boxW / scale;
    const cropHeight = maxPan.boxH / scale;

    const centerX = (imgW - cropWidth) / 2;
    const centerY = (imgH - cropHeight) / 2;

    let nx = centerX - (cropOffset.x / scale);
    let ny = centerY - (cropOffset.y / scale);

    nx = Math.max(0, Math.min(nx, imgW - cropWidth));
    ny = Math.max(0, Math.min(ny, imgH - cropHeight));

    const finalCrop = {
      x: Math.round(nx),
      y: Math.round(ny),
      width: Math.round(cropWidth),
      height: Math.round(cropHeight),
    };

    const frameConfig = (FRAME_CONFIGS as any)[imageOptions.frame || ''] || { scale: 1, offsetY: 0 };

    // Scale factor to map screen points to actual image pixels using exact measured UI width
    const actualUiWidth = uiCanvasWidths[item.id] || CARD_WIDTH;
    const renderScale = cropWidth / actualUiWidth;

    const hasCrop = cropRatio !== null || zoomScale > 1 || cropOffset.x !== 0 || cropOffset.y !== 0;

    return {
      ...imageOptions,
      rotateDegrees: (imageOptions.rotateDegrees || 0) + straightenAngle,
      ...(hasCrop ? { crop: finalCrop } : {}),
      imageAspectRatio: imgW / (imgH || 1),
      frameScale: imageOptions.frame ? frameConfig.scale : 1,
      frameOffsetY: imageOptions.frame ? (frameConfig.offsetY || 0) : 0,
      overlays: overlays.map(o => ({
        text: o.text,
        // Add 12px padding to match the visual position in the container
        x: (o.x + 12) * renderScale,
        y: (o.y + 12) * renderScale,
        color: o.color,
        fontSize: o.fontSize * renderScale,
      })),
      frameUri: imageOptions.frame && FRAME_IMAGES[imageOptions.frame] 
        ? Image.resolveAssetSource(FRAME_IMAGES[imageOptions.frame]).uri 
        : undefined,
    };
  }, [imageOptions, cropOffset, maxPan, dimensions, item, cropRatio, straightenAngle, overlays]);

  // For visual trim

  const duration = item.durationMs ?? 10_000;
  const durationRef = useRef(duration);
  useEffect(() => {
    durationRef.current = duration;
  }, [duration]);

  const formatTime = (ms: number) => {
    const totalSec = Math.floor(ms / 1000);
    const mins = Math.floor(totalSec / 60);
    const secs = totalSec % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const handleTimelineScroll = (e: any) => {
    if (isUserScrolling.current) {
      const x = e.nativeEvent.contentOffset.x;
      const time = (x / TIMELINE_WIDTH) * duration;
      const clampedTime = Math.max(trimStart, Math.min(trimEnd, time));
      setCurrentTimeMs(clampedTime);
      throttledSeek(clampedTime);
    }
  };

  useEffect(() => {
    if (videoPaused || item.type !== 'video' || !isEditingVideo) return;
    let lastTime = Date.now();
    const interval = setInterval(() => {
      const now = Date.now();
      const delta = now - lastTime;
      lastTime = now;
      setCurrentTimeMs((prev) => {
        let next = prev + delta;
        if (next >= duration) {
          next = 0;
        }
        return next;
      });
    }, 100);
    return () => clearInterval(interval);
  }, [videoPaused, duration, item.type, isEditingVideo]);

  const startX = useRef((trimStart / duration) * TIMELINE_WIDTH);
  const endX = useRef((trimEnd / duration) * TIMELINE_WIDTH);

  useEffect(() => {
    startX.current = (trimStart / duration) * TIMELINE_WIDTH;
  }, [trimStart, duration]);

  useEffect(() => {
    endX.current = (trimEnd / duration) * TIMELINE_WIDTH;
  }, [trimEnd, duration]);

  useEffect(() => {
    if (item.type === 'video' && thumbnails.length === 0) {
      const generateThumbs = async () => {
        const count = 10;
        const uris = [];
        for (let i = 0; i < count; i++) {
          const time = (i / (count - 1)) * duration;
          try {
            const uri = await captureFrame(item.uri, { timeMs: time });
            uris.push(uri);
          } catch (e) {
            console.error('Thumb extraction error', e);
          }
        }
        setThumbnails(uris);
      };
      generateThumbs();
    }
  }, [item.type, item.uri, duration, thumbnails.length]);

  const leftOverlayRef = useRef<View>(null);
  const rightOverlayRef = useRef<View>(null);
  const selectionRangeRef = useRef<View>(null);
  const leftHandleRef = useRef<View>(null);
  const rightHandleRef = useRef<View>(null);

  const updateNativeRefs = (newStartX: number, newEndX: number) => {
    leftOverlayRef.current?.setNativeProps({ style: { width: newStartX } });
    rightOverlayRef.current?.setNativeProps({ style: { left: newEndX } });
    selectionRangeRef.current?.setNativeProps({ style: { left: newStartX, width: newEndX - newStartX } });
    leftHandleRef.current?.setNativeProps({ style: { left: newStartX - 16 } });
    rightHandleRef.current?.setNativeProps({ style: { left: newEndX - 16 } });
  };

  const startPanOffset = useRef(0);
  const startPan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onStartShouldSetPanResponderCapture: () => true,
      onMoveShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponderCapture: () => true,
      onPanResponderGrant: () => {
        pushToHistory();
        startPanOffset.current = startX.current;
        isDraggingHandle.current = true;
        setScrollEnabled(false);
      },
      onPanResponderMove: (_, gesture) => {
        let newX = Math.max(0, Math.min(endX.current - 32, startPanOffset.current + gesture.dx));
        let newTime = (newX / TIMELINE_WIDTH) * durationRef.current;
        
        const currentTrimEnd = (endX.current / TIMELINE_WIDTH) * durationRef.current;
        if (maxVideoDurationMs && currentTrimEnd - newTime > maxVideoDurationMs) {
          newTime = currentTrimEnd - maxVideoDurationMs;
          newX = (newTime / durationRef.current) * TIMELINE_WIDTH;
        }

        startX.current = newX;
        updateNativeRefs(newX, endX.current);
        throttledSeek(newTime);
      },
      onPanResponderRelease: () => {
        isDraggingHandle.current = false;
        setScrollEnabled(true);
        setTrimStart((startX.current / TIMELINE_WIDTH) * durationRef.current);
        setTrimEnd((endX.current / TIMELINE_WIDTH) * durationRef.current);
        setSeekToMs(-1);
      },
      onPanResponderTerminate: () => {
        isDraggingHandle.current = false;
        setScrollEnabled(true);
        setTrimStart((startX.current / TIMELINE_WIDTH) * durationRef.current);
        setTrimEnd((endX.current / TIMELINE_WIDTH) * durationRef.current);
        setSeekToMs(-1);
      }
    })
  ).current;

  const middlePanOffsetStart = useRef(0);
  const middlePanOffsetEnd = useRef(0);
  
  const middlePan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onStartShouldSetPanResponderCapture: () => true,
      onMoveShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponderCapture: () => true,
      onPanResponderGrant: () => {
        pushToHistory();
        middlePanOffsetStart.current = startX.current;
        middlePanOffsetEnd.current = endX.current;
        isDraggingHandle.current = true;
        setScrollEnabled(false);
      },
      onPanResponderMove: (_, gesture) => {
        const windowWidth = middlePanOffsetEnd.current - middlePanOffsetStart.current;
        
        let newStartX = middlePanOffsetStart.current + gesture.dx;
        let newEndX = middlePanOffsetEnd.current + gesture.dx;
        
        if (newStartX < 0) {
          newStartX = 0;
          newEndX = windowWidth;
        }
        if (newEndX > TIMELINE_WIDTH) {
          newEndX = TIMELINE_WIDTH;
          newStartX = TIMELINE_WIDTH - windowWidth;
        }

        startX.current = newStartX;
        endX.current = newEndX;

        const newStartTime = (newStartX / TIMELINE_WIDTH) * durationRef.current;
        updateNativeRefs(newStartX, newEndX);
        throttledSeek(newStartTime);
      },
      onPanResponderRelease: () => {
        isDraggingHandle.current = false;
        setScrollEnabled(true);
        setTrimStart((startX.current / TIMELINE_WIDTH) * durationRef.current);
        setTrimEnd((endX.current / TIMELINE_WIDTH) * durationRef.current);
        setSeekToMs(-1);
      },
      onPanResponderTerminate: () => {
        isDraggingHandle.current = false;
        setScrollEnabled(true);
        setTrimStart((startX.current / TIMELINE_WIDTH) * durationRef.current);
        setTrimEnd((endX.current / TIMELINE_WIDTH) * durationRef.current);
        setSeekToMs(-1);
      }
    })
  ).current;

  const endPanOffset = useRef(0);
  const endPan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onStartShouldSetPanResponderCapture: () => true,
      onMoveShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponderCapture: () => true,
      onPanResponderGrant: () => {
        pushToHistory();
        endPanOffset.current = endX.current;
        isDraggingHandle.current = true;
        setScrollEnabled(false);
      },
      onPanResponderMove: (_, gesture) => {
        let newX = Math.min(TIMELINE_WIDTH, Math.max(startX.current + 32, endPanOffset.current + gesture.dx));
        let newTime = (newX / TIMELINE_WIDTH) * durationRef.current;

        const currentTrimStart = (startX.current / TIMELINE_WIDTH) * durationRef.current;
        if (maxVideoDurationMs && newTime - currentTrimStart > maxVideoDurationMs) {
          newTime = currentTrimStart + maxVideoDurationMs;
          newX = (newTime / durationRef.current) * TIMELINE_WIDTH;
        }

        endX.current = newX;
        updateNativeRefs(startX.current, newX);
        throttledSeek(newTime);
      },
      onPanResponderRelease: () => {
        isDraggingHandle.current = false;
        setScrollEnabled(true);
        setTrimStart((startX.current / TIMELINE_WIDTH) * durationRef.current);
        setTrimEnd((endX.current / TIMELINE_WIDTH) * durationRef.current);
        setSeekToMs(-1);
      },
      onPanResponderTerminate: () => {
        isDraggingHandle.current = false;
        setScrollEnabled(true);
        setTrimStart((startX.current / TIMELINE_WIDTH) * durationRef.current);
        setTrimEnd((endX.current / TIMELINE_WIDTH) * durationRef.current);
        setSeekToMs(-1);
      }
    })
  ).current;
  // Instagram‑style filter presets – extended
  const FILTERS = {
    // Classics
    none: { label: 'Normal', brightness: 0, contrast: 1, saturation: 1, grayscale: false },
    clarendon: { label: 'Clarendon', brightness: 0.1, contrast: 1.2, saturation: 1.3, grayscale: false },
    gingham: { label: 'Gingham', brightness: 0.05, contrast: 0.9, saturation: 0.8, grayscale: false },
    moon: { label: 'Moon', brightness: 0.05, contrast: 1.1, saturation: 0, grayscale: true },
    lark: { label: 'Lark', brightness: 0.08, contrast: 1.15, saturation: 1.1, grayscale: false },
    reyes: { label: 'Reyes', brightness: 0.15, contrast: 0.85, saturation: 0.75, grayscale: false },
    juno: { label: 'Juno', brightness: 0.07, contrast: 1.15, saturation: 1.3, grayscale: false },
    slumber: { label: 'Slumber', brightness: -0.05, contrast: 0.9, saturation: 0.85, grayscale: false },
    crema: { label: 'Crema', brightness: 0.05, contrast: 0.95, saturation: 0.9, grayscale: false },
    ludwig: { label: 'Ludwig', brightness: 0.05, contrast: 1.1, saturation: 1.2, grayscale: false },
    aden: { label: 'Aden', brightness: 0.1, contrast: 0.9, saturation: 0.8, grayscale: false },
    perpetua: { label: 'Perpetua', brightness: 0.05, contrast: 1.05, saturation: 1.15, grayscale: false },
    amaro: { label: 'Amaro', brightness: 0.1, contrast: 1.1, saturation: 1.1, grayscale: false },
    mayfair: { label: 'Mayfair', brightness: 0.06, contrast: 1.1, saturation: 1.2, grayscale: false },
    rise: { label: 'Rise', brightness: 0.09, contrast: 1.05, saturation: 1.1, grayscale: false },
    valencia: { label: 'Valencia', brightness: 0.02, contrast: 1.05, saturation: 1.0, grayscale: false },
    xpro2: { label: 'X-Pro II', brightness: 0.03, contrast: 1.3, saturation: 1.25, grayscale: false },
    sierra: { label: 'Sierra', brightness: 0.05, contrast: 0.9, saturation: 0.9, grayscale: false },
    willow: { label: 'Willow', brightness: 0.05, contrast: 0.85, saturation: 0, grayscale: true },
    lofi: { label: 'Lo-Fi', brightness: 0.02, contrast: 1.4, saturation: 1.5, grayscale: false },
    inkwell: { label: 'Inkwell', brightness: 0.02, contrast: 1.3, saturation: 0, grayscale: true },
    nashville: { label: 'Nashville', brightness: 0.05, contrast: 1.1, saturation: 1.0, grayscale: false },

    // Cities
    rio: { label: 'Rio de Janeiro', brightness: 0.08, contrast: 1.2, saturation: 1.4, grayscale: false },
    tokyo: { label: 'Tokyo', brightness: -0.02, contrast: 1.1, saturation: 1.0, grayscale: false },
    cairo: { label: 'Cairo', brightness: 0.05, contrast: 1.0, saturation: 1.1, grayscale: false },
    jaipur: { label: 'Jaipur', brightness: 0.07, contrast: 1.05, saturation: 1.2, grayscale: false },
    newyork: { label: 'New York', brightness: 0.02, contrast: 1.3, saturation: 0.9, grayscale: false },
    buenosaires: { label: 'Buenos Aires', brightness: 0.04, contrast: 1.1, saturation: 1.15, grayscale: false },
    abudhabi: { label: 'Abu Dhabi', brightness: 0.06, contrast: 1.05, saturation: 1.1, grayscale: false },
    jakarta: { label: 'Jakarta', brightness: 0.03, contrast: 1.15, saturation: 1.25, grayscale: false },
    melbourne: { label: 'Melbourne', brightness: 0.05, contrast: 1.0, saturation: 1.05, grayscale: false },
    oslo: { label: 'Oslo', brightness: -0.05, contrast: 1.1, saturation: 0.9, grayscale: false },
    la: { label: 'Los Angeles', brightness: 0.1, contrast: 1.1, saturation: 1.3, grayscale: false },
    paris: { label: 'Paris', brightness: 0.08, contrast: 0.95, saturation: 1.1, grayscale: false },

    // Special & Effects
    wideangle: { label: 'Wide Angle', brightness: 0.05, contrast: 1.1, saturation: 1.1, grayscale: false, effect: 'vignette' },
    wavy: { label: 'Wavy', brightness: 0.02, contrast: 1.05, saturation: 1.2, grayscale: false, effect: 'vignette' },
    lores: { label: 'LO-Res', brightness: 0.05, contrast: 1.1, saturation: 1.15, grayscale: false, effect: 'pixelize' },
    moire: { label: 'MOire', brightness: 0, contrast: 1.1, saturation: 1.0, grayscale: false, effect: 'grain' },
    handheld: { label: 'Handheld', brightness: 0, contrast: 1.0, saturation: 1.0, grayscale: false, effect: 'vignette' },
    zoomblur: { label: 'Zoom Blur', brightness: 0.05, contrast: 1.15, saturation: 1.2, grayscale: false, effect: 'vignette' },
    softlight: { label: 'Soft Light', brightness: 0.1, contrast: 0.9, saturation: 1.0, grayscale: false },
    colorleak: { label: 'Color Leak', brightness: 0.05, contrast: 1.1, saturation: 1.2, grayscale: false },
    halo: { label: 'Halo', brightness: 0.15, contrast: 1.05, saturation: 1.1, grayscale: false },
    gritty: { label: 'Gritty', brightness: -0.05, contrast: 1.5, saturation: 0.8, grayscale: false, effect: 'grain' },
    grainy: { label: 'Grainy', brightness: 0, contrast: 1.2, saturation: 1.0, grayscale: false, effect: 'grain' },
    midnight: { label: 'Midnight', brightness: -0.15, contrast: 1.3, saturation: 0.7, grayscale: false },
    emerald: { label: 'Emerald', brightness: 0, contrast: 1.1, saturation: 1.2, grayscale: false },
    rosy: { label: 'Rosy', brightness: 0.05, contrast: 1.0, saturation: 1.2, grayscale: false },
    hyper: { label: 'Hyper', brightness: 0.05, contrast: 1.5, saturation: 2.0, grayscale: false },
    graphite: { label: 'Graphite', brightness: -0.05, contrast: 1.4, saturation: 0, grayscale: true },

    // Boosts & Fades
    boostcool: { label: 'Boost Cool', brightness: 0.02, contrast: 1.1, saturation: 1.2, grayscale: false },
    boostwarm: { label: 'Boost Warm', brightness: 0.02, contrast: 1.1, saturation: 1.2, grayscale: false },
    boost: { label: 'Boost', brightness: 0.05, contrast: 1.2, saturation: 1.3, grayscale: false },
    simplecool: { label: 'Simple Cool', brightness: 0.02, contrast: 1.0, saturation: 1.1, grayscale: false },
    simplewarm: { label: 'Simple Warm', brightness: 0.02, contrast: 1.0, saturation: 1.1, grayscale: false },
    simple: { label: 'Simple', brightness: 0.05, contrast: 1.05, saturation: 1.05, grayscale: false },
    fadecool: { label: 'Fade Cool', brightness: 0.08, contrast: 0.85, saturation: 0.8, grayscale: false },
    fadewarm: { label: 'Fade Warm', brightness: 0.08, contrast: 0.85, saturation: 0.8, grayscale: false },
    fade: { label: 'Fade', brightness: 0.1, contrast: 0.8, saturation: 0.75, grayscale: false },
    vivid: { label: 'Vivid', brightness: 0.05, contrast: 1.25, saturation: 1.4, grayscale: false },
    cool: { label: 'Cool', brightness: 0.02, contrast: 1.05, saturation: 1.1, grayscale: false },
    warm: { label: 'Warm', brightness: 0.02, contrast: 1.05, saturation: 1.1, grayscale: false },
    mono: { label: 'Mono', brightness: 0.0, contrast: 1.1, saturation: 0.0, grayscale: true },
    noir: { label: 'Noir', brightness: -0.05, contrast: 1.4, saturation: 0.0, grayscale: true },
    chrome: { label: 'Chrome', brightness: 0.05, contrast: 1.2, saturation: 1.3, grayscale: false },
  };



  const imageTransform = useMemo(() => {
    const transforms = [] as any[];
    const totalRotation = (imageOptions.rotateDegrees || 0) + straightenAngle;
    if (totalRotation) {
      transforms.push({ rotate: `${totalRotation}deg` });
    }
    transforms.push({ scaleX: imageOptions.flipX ? -1 : 1 });
    transforms.push({ scaleY: imageOptions.flipY ? -1 : 1 });
    return transforms;
  }, [imageOptions.flipX, imageOptions.flipY, imageOptions.rotateDegrees, straightenAngle]);

  const adjustImage = (patch: Partial<ImageEditOptions>) => {
    pushToHistory();
    setImageOptions((prev) => ({ ...prev, ...patch }));
  };

  const handleSetRatio = (ratio: number | 'custom' | null) => {
    pushToHistory();
    setCropRatio(ratio);
    setCropOffset({ x: 0, y: 0 });
    setZoomScale(1);
    setCropResizeScale(1);
    setCropResizeScaleX(1);
    setCropResizeScaleY(1);
    if (ratio === null) {
      setCrop(null);
    } else if (ratio === 'custom') {
      if (!crop) {
        setCrop({ x: 0, y: 0, width: dimensions.width, height: dimensions.height });
      }
    } else {
      let imgW = dimensions.width;
      let imgH = dimensions.height;
      if ((imageOptions.rotateDegrees || 0) % 180 !== 0) {
        imgW = dimensions.height;
        imgH = dimensions.width;
      }
      if (!imgW || !imgH) return;

      let newW, newH;
      const imgRatio = imgW / imgH;
      if (imgRatio > ratio) {
        newH = imgH;
        newW = imgH * ratio;
      } else {
        newW = imgW;
        newH = imgW / ratio;
      }
      setCrop({
        x: Math.round((imgW - newW) / 2),
        y: Math.round((imgH - newH) / 2),
        width: Math.round(newW),
        height: Math.round(newH),
      });
    }
  };

  const currentQuickRatioLabel = useMemo(() => {
    if (cropRatio === 1) return 'Square';
    if (cropRatio === 9 / 16) return 'Portrait';
    return 'Portrait';
  }, [cropRatio]);

  const applyQuickRatio = (mode: 'portrait' | 'square') => {
    if (mode === 'square') {
      handleSetRatio(1);
    } else {
      handleSetRatio(9 / 16);
    }
    setShowQuickRatioMenu(false);
  };

  useEffect(() => {
  }, [item.type, panel, cropRatio]);

  useEffect(() => {
  }, []);

  const applyFilterPreset = (preset: string) => {
    pushToHistory();
    setActiveFilter(preset);
    const filter = (FILTERS as any)[preset] || FILTERS.none;
    const overlayColor = getPreviewOverlayColor(preset);
    const overlayOpacity = getPreviewOverlayOpacity(preset);
    setImageOptions((prev) => ({
      ...prev,
      brightness: filter.brightness,
      contrast: filter.contrast,
      saturation: filter.saturation,
      grayscale: filter.grayscale,
      effect: filter.effect,
      tintColor: overlayColor !== 'transparent' ? overlayColor : undefined,
      tintOpacity: overlayColor !== 'transparent' ? overlayOpacity : undefined,
    }));
  };

  const getFilterColor = (key: string) => {
    switch (key) {
      case 'clarendon': return '#38bdf8';
      case 'gingham': return '#f1f5f9';
      case 'moon': return '#64748b';
      case 'lark': return '#fbbf24';
      case 'reyes': return '#fed7aa';
      case 'juno': return '#f43f5e';
      case 'slumber': return '#a8a29e';
      case 'crema': return '#fdf4ff';
      case 'ludwig': return '#ea580c';
      case 'aden': return '#db2777';
      case 'perpetua': return '#0d9488';
      case 'amaro': return '#a5f3fc';
      case 'mayfair': return '#fda4af';
      case 'rise': return '#fdba74';
      case 'valencia': return '#fbbf24';
      case 'xpro2': return '#4ade80';
      case 'sierra': return '#a8a29e';
      case 'willow': return '#94a3b8';
      case 'lofi': return '#f97316';
      case 'inkwell': return '#334155';
      case 'nashville': return '#fecaca';
      case 'rio': return '#fbbf24';
      case 'tokyo': return '#22d3ee';
      case 'cairo': return '#eab308';
      case 'jaipur': return '#f472b6';
      case 'newyork': return '#475569';
      case 'buenosaires': return '#92400e';
      case 'abudhabi': return '#f59e0b';
      case 'jakarta': return '#0d9488';
      case 'melbourne': return '#ecfdf5';
      case 'oslo': return '#0ea5e9';
      case 'la': return '#fde047';
      case 'paris': return '#fbcfe8';
      case 'emerald': return '#10b981';
      case 'rosy': return '#fb7185';
      case 'midnight': return '#1e1b4b';
      default: return '#334155';
    }
  };

  const getPreviewOverlayColor = (key: string) => {
    switch (key) {
      case 'clarendon': return '#38bdf8';
      case 'gingham': return '#e2e8f0';
      case 'lark': return '#fbbf24';
      case 'reyes': return '#fff7ed';
      case 'juno': return '#f43f5e';
      case 'aden': return '#f472b6';
      case 'perpetua': return '#2dd4bf';
      case 'moon': return '#000000';
      case 'amaro': return '#38bdf8';
      case 'mayfair': return '#fb7185';
      case 'rise': return '#f59e0b';
      case 'valencia': return '#f59e0b';
      case 'nashville': return '#f472b6';
      case 'rio': return '#f59e0b';
      case 'tokyo': return '#06b6d4';
      case 'cairo': return '#f59e0b';
      case 'jaipur': return '#ec4899';
      case 'newyork': return '#64748b';
      case 'buenosaires': return '#78350f';
      case 'abudhabi': return '#f59e0b';
      case 'jakarta': return '#059669';
      case 'oslo': return '#3b82f6';
      case 'la': return '#fbbf24';
      case 'paris': return '#f472b6';
      case 'boostcool': return '#3b82f6';
      case 'boostwarm': return '#f59e0b';
      case 'simplecool': return '#3b82f6';
      case 'simplewarm': return '#f59e0b';
      case 'fadecool': return '#3b82f6';
      case 'fadewarm': return '#f59e0b';
      case 'colorleak': return '#ef4444';
      case 'midnight': return '#1e1b4b';
      case 'emerald': return '#10b981';
      case 'rosy': return '#f43f5e';
      case 'vivid': return '#fbbf24';
      case 'cool': return '#3b82f6';
      case 'warm': return '#f97316';
      case 'fade': return '#e2e8f0';
      case 'mono': return '#6b7280';
      case 'noir': return '#000000';
      case 'chrome': return '#06b6d4';
      default: return 'transparent';
    }
  };

  const getPreviewOverlayOpacity = (key: string) => {
    if (key === 'none') return 0;
    if (key === 'moon' || key === 'midnight' || key === 'graphite' || key === 'noir') return 0.2;
    if (key === 'colorleak') return 0.25;
    if (key === 'halo') return 0.15;
    if (key === 'mono') return 0.25;
    if (key === 'fade') return 0.2;
    return 0.12;
  };

  const adjustTrim = (deltaStartMs: number, deltaEndMs: number) => {
    setTrimStart((prevStart) => {
      let newStart = Math.max(0, prevStart + deltaStartMs);
      setTrimEnd((prevEnd) => {
        let newEnd = Math.max(newStart + 500, prevEnd + deltaEndMs);
        if (item.durationMs) {
          newEnd = Math.min(newEnd, item.durationMs);
        }
        if (maxVideoDurationMs && newEnd - newStart > maxVideoDurationMs) {
          if (deltaEndMs > 0) {
            newEnd = newStart + maxVideoDurationMs;
          } else if (deltaStartMs < 0) {
            newStart = newEnd - maxVideoDurationMs;
          }
        }
        return newEnd;
      });
      return newStart;
    });
  };

  const handleDownload = async () => {
    try {
      setSaving(true);
      let exportUri = item.uri;
      if (item.type === 'image') {
        exportUri = await editImage(item.uri, activeOptions);
        if (selectedMusic) {
          exportUri = await trimVideo(exportUri, {
            isImage: true,
            musicUri: selectedMusic.url,
            rotateDegrees: 0,
            flipX: false,
            flipY: false,
            brightness: 0,
            contrast: 1,
            saturation: 1,
            grayscale: false,
          });
        }
      } else {
        const safeEndMs = Math.min(trimEnd, item.durationMs || 10000);
        let safeStartMs = Math.min(trimStart, Math.max(0, safeEndMs - 100));
        
        if (maxVideoDurationMs && safeEndMs - safeStartMs > maxVideoDurationMs) {
          safeStartMs = safeEndMs - maxVideoDurationMs;
        }
        
        const isFullTrim = safeStartMs === 0 && safeEndMs >= (item.durationMs || 10000);
        
        exportUri = await trimVideo(item.uri, {
          startMs: safeStartMs,
          endMs: safeEndMs,
          mute: isMuted,
          ...(selectedMusic?.url ? { musicUri: selectedMusic.url } : {}),
          ...activeOptions,
        });
      }
      await saveToGallery(exportUri, (selectedMusic || item.type === 'video') ? 'video' : 'image');
      Alert.alert('Success', 'Media saved to your gallery!');
    } catch (err: any) {
      Alert.alert('Download failed', err?.message ?? 'Could not save to gallery.');
    } finally {
      setSaving(false);
    }
  };

  const handleSaveAll = async () => {
    try {
      setSaving(true);
      saveEditsForIndex(activeIndex);

      const updatedItems = [...items];
      let cumulativeMusicOffsetMs = 0;

      for (let i = 0; i < items.length; i++) {
        const targetItem = items[i];

        let edits = editsHistoryRef.current[targetItem.id];
        if (i === activeIndex) {
          edits = {
            activeFilter,
            imageOptions,
            trimStart,
            trimEnd,
            overlays,
            cropRatio,
            cropOffset,
            zoomScale,
            straightenAngle,
            isMuted,
          };
        }

        if (edits) {
          const opts = i === activeIndex ? activeOptions : buildOptionsForItem(targetItem, edits);

          if (targetItem.type === 'image') {
            let outUri = await editImage(targetItem.uri, opts);
            if (selectedMusic) {
              outUri = await trimVideo(outUri, {
                isImage: true,
                musicUri: selectedMusic.url,
                musicOffsetMs: cumulativeMusicOffsetMs,
                rotateDegrees: 0,
                flipX: false,
                flipY: false,
                brightness: 0,
                contrast: 1,
                saturation: 1,
                grayscale: false,
              });
            }
            updatedItems[i] = {
              ...targetItem,
              uri: outUri,
              thumbnailUri: outUri,
            };
            cumulativeMusicOffsetMs += 10000; // Images are 10s by default
          } else {
            const originalDuration = targetItem.durationMs || 10000;
            const safeEndMs = Math.min(edits.trimEnd, originalDuration);
            let safeStartMs = Math.min(edits.trimStart, Math.max(0, safeEndMs - 100));
            
            if (maxVideoDurationMs && safeEndMs - safeStartMs > maxVideoDurationMs) {
              safeStartMs = safeEndMs - maxVideoDurationMs;
            }
            
            const isFullTrim = safeStartMs === 0 && safeEndMs >= originalDuration;


            const outUri = await trimVideo(targetItem.uri, {
              startMs: safeStartMs,
              endMs: safeEndMs,
              mute: edits.isMuted,
              ...(selectedMusic?.url ? { musicUri: selectedMusic.url, musicOffsetMs: cumulativeMusicOffsetMs } : {}),
              ...opts,
            });


            let newThumb = undefined;
            try {
              newThumb = await captureFrame(outUri, { timeMs: 0 });
            } catch (e) {
              console.warn('Could not generate filtered thumb', e);
            }

            const newDuration = edits.trimEnd - edits.trimStart;
            updatedItems[i] = {
              ...targetItem,
              uri: outUri,
              thumbnailUri: newThumb ? newThumb : targetItem.thumbnailUri,
              durationMs: newDuration,
            };
            cumulativeMusicOffsetMs += newDuration;
          }
        } else {
          if (targetItem.type === 'image') {
            if (selectedMusic) {
              const outUri = await trimVideo(targetItem.uri, {
                isImage: true,
                musicUri: selectedMusic.url,
                musicOffsetMs: cumulativeMusicOffsetMs,
                rotateDegrees: 0,
                flipX: false,
                flipY: false,
                brightness: 0,
                contrast: 1,
                saturation: 1,
                grayscale: false,
              });
              cumulativeMusicOffsetMs += 10000;
              updatedItems[i] = {
                ...targetItem,
                uri: outUri,
                thumbnailUri: outUri,
              };
            }
          } else {
            const needsTrim = selectedMusic || (maxVideoDurationMs && (!targetItem.durationMs || targetItem.durationMs > maxVideoDurationMs));
            if (needsTrim) {
              const safeEndMs = maxVideoDurationMs ? Math.min(targetItem.durationMs || 10000, maxVideoDurationMs) : (targetItem.durationMs || 10000);
              const outUri = await trimVideo(targetItem.uri, {
                startMs: 0,
                endMs: safeEndMs,
                mute: isMuted,
                ...(selectedMusic?.url ? { musicUri: selectedMusic.url, musicOffsetMs: cumulativeMusicOffsetMs } : {}),
                rotateDegrees: 0,
                flipX: false,
                flipY: false,
                brightness: 0,
                contrast: 1,
                saturation: 1,
                grayscale: false,
              });

              let newThumb = undefined;
              try {
                newThumb = await captureFrame(outUri, { timeMs: 0 });
              } catch (e) {
                console.warn('Could not generate filtered thumb', e);
              }

              updatedItems[i] = {
                ...targetItem,
                uri: outUri,
                thumbnailUri: newThumb ? newThumb : targetItem.thumbnailUri,
                durationMs: safeEndMs,
              };
              cumulativeMusicOffsetMs += safeEndMs;
            } else {
              cumulativeMusicOffsetMs += targetItem.durationMs || 10000;
            }
          }
        }
      }

      onSaved(updatedItems);
    } catch (err: any) {
      console.error('EXPORT / SAVE EDITS FAILED:', err?.message ?? err);
    } finally {
      setSaving(false);
    }
  };

  const renderCard = ({ item: cardItem, index }: { item: MediaItem; index: number }) => {
    const isActive = index === activeIndex;

    // Read the edits for this item
    const edits = isActive
      ? {
        activeFilter,
        imageOptions,
        overlays,
        cropRatio,
        cropOffset,
        zoomScale,
        straightenAngle,
      }
      : editsHistoryRef.current[cardItem.id] || {
        activeFilter: 'none',
        imageOptions: { frame: '' },
        overlays: [],
        cropRatio: null,
        cropOffset: { x: 0, y: 0 },
        zoomScale: 1,
        straightenAngle: 0,
      };

    const frameConfig = (FRAME_CONFIGS as any)[edits.imageOptions.frame || ''] || { scale: 1, offsetY: 0 };
    const currentScale = edits.imageOptions.frame ? frameConfig.scale : 1;
    const cardDim = dimensionsMap[cardItem.id] || { width: 1080, height: 1920 };
    const currentYOffset = edits.imageOptions.frame ? (frameConfig.offsetY || 0) * (cardDim.height || 1000) : 0;

    const cardTransform = [];
    if (edits.imageOptions.rotateDegrees) {
      cardTransform.push({ rotate: `${edits.imageOptions.rotateDegrees}deg` });
    }
    if (edits.imageOptions.flipX) {
      cardTransform.push({ scaleX: -1 });
    }
    if (edits.imageOptions.flipY) {
      cardTransform.push({ scaleY: -1 });
    }

    const cardAspect = typeof edits.cropRatio === 'number' ? edits.cropRatio : (cardDim.width / (cardDim.height || 1));

    return (
      <View style={[styles.cardContainer, { width: CARD_WIDTH, marginHorizontal: CARD_MARGIN }]}>
        <View
          style={[
            styles.cardPreviewBox,
            {
              aspectRatio: cardAspect,
              backgroundColor: '#111',
              borderRadius: 16,
              overflow: 'hidden',
              width: '100%',
              maxWidth: CARD_WIDTH,
              alignSelf: 'center',
            }
          ]}
          onLayout={(e) => {
            const { width } = e.nativeEvent.layout;
            if (width > 0) {
              setUiCanvasWidths(prev => ({ ...prev, [cardItem.id]: width }));
            }
          }}
          {...(isActive && panel === 'transform' && cardItem.type === 'image' ? cropPan.panHandlers : {})}
        >
          {cardItem.type === 'image' ? (
            <Image
              source={{ uri: cardItem.uri }}
              style={[
                styles.preview,
                {
                  transform: [
                    { scale: currentScale },
                    { translateX: edits.cropOffset.x },
                    { translateY: edits.cropOffset.y + currentYOffset },
                    { scale: edits.zoomScale },
                    ...cardTransform
                  ]
                }
              ]}
              resizeMode={edits.cropRatio ? "cover" : "contain"}
            />
          ) : (
            <Pressable onPress={() => isActive && setVideoPaused(v => !v)} style={[styles.videoPreview, { transform: [{ scale: currentScale }, { translateX: edits.cropOffset.x }, { translateY: edits.cropOffset.y + currentYOffset }, { scale: edits.zoomScale }, ...cardTransform] }]}>
              <VideoPreview
                uri={cardItem.uri}
                paused={!isActive || videoPaused}
                muted={isActive ? isMuted : true}
                style={styles.previewContainerResized}
                resizeMode={edits.cropRatio ? "cover" : "contain"}
              />
              {isActive && videoPaused && (
                <View style={styles.previewOverlay}>
                  <View style={styles.playPauseCircle}>
                    <Ionicons name="play" size={22} color="#fff" />
                  </View>
                </View>
              )}
            </Pressable>
          )}

          {/* Frame Overlay */}
          {edits.imageOptions.frame && FRAME_IMAGES[edits.imageOptions.frame] && (
            <View
              style={[StyleSheet.absoluteFill, { zIndex: 10, justifyContent: 'center', alignItems: 'center' }]}
              pointerEvents="none"
            >
              <Image
                source={FRAME_IMAGES[edits.imageOptions.frame]}
                style={{ width: '100%', height: '100%' }}
                resizeMode="stretch"
              />
            </View>
          )}

          {/* Color Filter Overlay */}
          <View
            pointerEvents="none"
            style={[
              StyleSheet.absoluteFill,
              {
                backgroundColor: getPreviewOverlayColor(edits.activeFilter),
                opacity: getPreviewOverlayOpacity(edits.activeFilter),
                zIndex: 8,
              },
            ]}
          />

          {/* Brightness Overlay */}
          <View
            pointerEvents="none"
            style={[
              StyleSheet.absoluteFill,
              {
                backgroundColor: (edits.imageOptions.brightness ?? 0) > 0 ? '#fff' : '#000',
                opacity: Math.min(0.6, Math.abs(edits.imageOptions.brightness ?? 0) * 0.5),
                zIndex: 9,
              },
            ]}
          />

          {/* Text Overlays */}
          {isActive && overlays.map((overlay) => {
            const responder = getTextResponder(overlay.id);
            const isSelected = editingTextId === overlay.id;
            return (
              <View
                key={overlay.id}
                style={[
                  styles.textOverlayContainer,
                  { left: overlay.x, top: overlay.y, zIndex: 20 },
                  isSelected && styles.selectedTextContainer
                ]}
                {...responder.panHandlers}
              >
                <View style={{ padding: 4 }}>
                  <Text style={[styles.textOverlay, { color: overlay.color, fontSize: overlay.fontSize }]}>
                    {overlay.text}
                  </Text>
                </View>
              </View>
            );
          })}

          {!isActive && edits.overlays && edits.overlays.map((overlay: any) => (
            <View
              key={overlay.id}
              style={[
                styles.textOverlayContainer,
                { left: overlay.x, top: overlay.y, zIndex: 20 }
              ]}
              pointerEvents="none"
            >
              <Text style={[styles.textOverlay, { color: overlay.color, fontSize: overlay.fontSize }]}>
                {overlay.text}
              </Text>
            </View>
          ))}

          {/* Sticker Overlays */}
          {isActive && stickers.map(s => (
            <View
              key={s.id}
              style={{ position: 'absolute', left: s.x, top: s.y, zIndex: 25 }}
              pointerEvents="box-none"
            >
              <Pressable onLongPress={() => removeSticker(s.id)}>
                <Text style={{ fontSize: s.size }}>{s.emoji}</Text>
              </Pressable>
            </View>
          ))}

          {/* Caption Overlays */}
          {isActive && captions.map(c => {
            const cs = CAPTION_STYLES.find(s => s.id === c.style) || CAPTION_STYLES[0];
            return (
              <View
                key={c.id}
                style={{ position: 'absolute', left: c.x, top: c.y, zIndex: 26, maxWidth: 220 }}
                pointerEvents="box-none"
              >
                <Pressable onLongPress={() => removeCaption(c.id)}>
                  <View style={{ backgroundColor: cs.bg, paddingHorizontal: 10, paddingVertical: 5, borderRadius: 6 }}>
                    <Text style={{ color: cs.color, fontWeight: cs.fontWeight, fontSize: 14 }}>{c.text}</Text>
                  </View>
                </Pressable>
              </View>
            );
          })}

          {/* Floating Crop Button */}
          {isActive && cardItem.type === 'image' && (
            <Pressable style={styles.cropIconBtn} onPress={() => onOpenCrop(cardItem)}>
              <Ionicons name="crop-outline" size={20} color="#fff" />
            </Pressable>
          )}
        </View>
      </View>
    );
  };

  const videoAspect = typeof cropRatio === 'number' ? cropRatio : (dimensions.width / (dimensions.height || 1));

  const carouselHeight = showMusicModal ? 280 : 380;

  return (
    <View style={styles.container}>
      {selectedMusic && (
        <Video
          source={{ uri: selectedMusic.url }}
          paused={musicPaused || (item.type === 'video' ? videoPaused : false)}
          repeat
          muted={false}
          style={{ width: 0, height: 0, position: 'absolute' }}
        />
      )}

      {items.length === 1 && item.type === 'video' ? (
        isEditingVideo ? (
          /* Render Edit Mode UI (Screenshot 2) */
          <View style={styles.editModeContainer}>
            {/* Top Header */}
            <View style={styles.editModeHeader}>
              <Pressable onPress={() => setIsEditingVideo(false)} style={styles.editModeBackBtn}>
                <Ionicons name="chevron-down" size={22} color="#fff" />
              </Pressable>
              <Pressable onPress={handleSaveAll} style={styles.editModeNextBtn} disabled={saving}>
                {saving ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <Ionicons name="arrow-forward" size={20} color="#fff" />
                )}
              </Pressable>
            </View>

            {/* Centered Small Video Player */}
            <View
              style={styles.editModePlayerContainer}
              {...(panel === 'transform' ? cropPan.panHandlers : {})}
            >
              <View
                onLayout={(e) => {
                  const { width } = e.nativeEvent.layout;
                  if (width > 0) {
                    setUiCanvasWidths(prev => ({ ...prev, [item.id]: width }));
                  }
                }}
                style={{
                  width: '100%',
                  aspectRatio: videoAspect || 1,
                  maxHeight: '100%',
                  justifyContent: 'center',
                  alignItems: 'center',
                  overflow: 'hidden',
                  backgroundColor: '#000',
                }}
              >
                <VideoPreview
                  uri={item.uri}
                  paused={videoPaused}
                  muted={isMuted}
                  style={[
                    styles.editModeVideo,
                    {
                      transform: [
                        { scale: zoomScale },
                        { translateX: cropOffset.x },
                        { translateY: cropOffset.y }
                      ]
                    }
                  ]}
                  resizeMode={cropRatio ? "cover" : "contain"}
                  trimStartMs={trimStart}
                  trimEndMs={trimEnd}
                  seekToMs={seekToMs}
                  onChange={(e) => {
                    const time = e.nativeEvent.currentTimeMs;
                    setCurrentTimeMs(time);
                    if (!isUserScrolling.current && !isDraggingHandle.current) {
                      const x = (time / duration) * TIMELINE_WIDTH;
                      timelineScrollRef.current?.scrollTo({ x, animated: false });
                    }
                  }}
                />

                {/* Frame/Overlay Overlay */}
                {imageOptions.frame && FRAME_IMAGES[imageOptions.frame] && (
                  <View
                    style={[StyleSheet.absoluteFill, { zIndex: 10, justifyContent: 'center', alignItems: 'center' }]}
                    pointerEvents="none"
                  >
                    <Image
                      source={FRAME_IMAGES[imageOptions.frame]}
                      style={{ width: '100%', height: '100%' }}
                      resizeMode="stretch"
                    />
                  </View>
                )}

                {/* Color Filter Overlay */}
                <View
                  pointerEvents="none"
                  style={[
                    StyleSheet.absoluteFill,
                    {
                      backgroundColor: getPreviewOverlayColor(activeFilter),
                      opacity: getPreviewOverlayOpacity(activeFilter),
                      zIndex: 8,
                    },
                  ]}
                />

                {/* Brightness Overlay */}
                <View
                  pointerEvents="none"
                  style={[
                    StyleSheet.absoluteFill,
                    {
                      backgroundColor: (imageOptions.brightness ?? 0) > 0 ? '#fff' : '#000',
                      opacity: Math.min(0.6, Math.abs(imageOptions.brightness ?? 0) * 0.5),
                      zIndex: 9,
                    },
                  ]}
                />

                {/* Low Contrast Overlay (emulated gray layer) */}
                {(imageOptions.contrast ?? 1) < 1 && (
                  <View
                    pointerEvents="none"
                    style={[
                      StyleSheet.absoluteFill,
                      {
                        backgroundColor: '#808080',
                        opacity: (1 - (imageOptions.contrast ?? 1)) * 0.4,
                        zIndex: 9,
                      },
                    ]}
                  />
                )}

                {/* High Contrast Overlay (emulated shadow enhancement) */}
                {(imageOptions.contrast ?? 1) > 1 && (
                  <View
                    pointerEvents="none"
                    style={[
                      StyleSheet.absoluteFill,
                      {
                        backgroundColor: '#000',
                        opacity: ((imageOptions.contrast ?? 1) - 1) * 0.15,
                        zIndex: 9,
                      },
                    ]}
                  />
                )}

                {/* Low Saturation / Grayscale Overlay (emulated gray desaturation) */}
                {(imageOptions.saturation ?? 1) < 1 && (
                  <View
                    pointerEvents="none"
                    style={[
                      StyleSheet.absoluteFill,
                      {
                        backgroundColor: '#808080',
                        opacity: (1 - (imageOptions.saturation ?? 1)) * 0.5,
                        zIndex: 9,
                      },
                    ]}
                  />
                )}

                {/* Text Overlays */}
                {overlays.map((overlay) => {
                  const responder = getTextResponder(overlay.id);
                  const isSelected = editingTextId === overlay.id;
                  return (
                    <View
                      key={overlay.id}
                      style={[
                        styles.textOverlayContainer,
                        { left: overlay.x, top: overlay.y, zIndex: 20 },
                        isSelected && styles.selectedTextContainer
                      ]}
                      {...responder.panHandlers}
                    >
                      <View style={{ padding: 4 }}>
                        <Text style={[styles.textOverlay, { color: overlay.color, fontSize: overlay.fontSize }]}>
                          {overlay.text}
                        </Text>
                      </View>
                    </View>
                  );
                })}
              </View>
            </View>

            {/* Video Player Controls */}
            <View style={styles.playerControlsRow}>
              <Pressable onPress={() => setVideoPaused(!videoPaused)} style={styles.editPlayPauseBtn}>
                <Ionicons name={videoPaused ? 'play' : 'pause'} size={20} color="#fff" />
              </Pressable>
              <Text style={styles.durationText}>
                {formatTime(currentTimeMs)} / {formatTime(duration)}
              </Text>

              <View style={styles.historyButtons}>
                <Pressable
                  style={[styles.historyBtn, undoStack.length === 0 && { opacity: 0.5 }]}
                  onPress={handleUndo}
                  disabled={undoStack.length === 0}
                >
                  <Ionicons name="arrow-undo" size={18} color="#fff" />
                </Pressable>
                <Pressable
                  style={[styles.historyBtn, redoStack.length === 0 && { opacity: 0.5 }]}
                  onPress={handleRedo}
                  disabled={redoStack.length === 0}
                >
                  <Ionicons name="arrow-redo" size={18} color="#fff" />
                </Pressable>
              </View>
            </View>

            {/* Timeline View */}
            <View style={styles.timelineSection}>
              {/* Scrollable Tracks & Ruler */}
              <ScrollView
                horizontal
                ref={timelineScrollRef}
                showsHorizontalScrollIndicator={false}
                scrollEnabled={scrollEnabled}
                onScroll={handleTimelineScroll}
                scrollEventThrottle={16}
                onScrollBeginDrag={() => {
                  isUserScrolling.current = true;
                  // Pause video when user starts scrubbing the timeline
                  setVideoPaused(true);
                }}
                onScrollEndDrag={() => {
                  if (!isMomentumScrolling.current) {
                    isUserScrolling.current = false;
                    setSeekToMs(-1);
                  }
                }}
                onMomentumScrollBegin={() => {
                  isMomentumScrolling.current = true;
                }}
                onMomentumScrollEnd={() => {
                  isMomentumScrolling.current = false;
                  isUserScrolling.current = false;
                  setSeekToMs(-1);
                }}
                contentContainerStyle={{
                  paddingHorizontal: SCREEN_WIDTH / 2,
                }}
              >
                <View style={{ width: TIMELINE_WIDTH }}>
                  {/* Ruler */}
                  <View style={styles.timelineRuler}>
                    <View style={styles.timelineRulerDot} />
                    <Text style={styles.timelineRulerText}>5s</Text>
                    <View style={styles.timelineRulerDot} />
                    <Text style={styles.timelineRulerText}>10s</Text>
                    <View style={styles.timelineRulerDot} />
                    <Text style={styles.timelineRulerText}>15s</Text>
                    <View style={styles.timelineRulerDot} />
                  </View>

                  <View style={styles.timelineTracksContainer}>
                    {/* Filmstrip video track */}
                    <View style={[styles.filmstripTrack, { overflow: 'visible' }]}>
                      <Pressable
                        style={styles.filmstrip}
                        onPress={(e) => {
                          const x = e.nativeEvent.locationX;
                          // Pause video and seek to the tapped position
                          setVideoPaused(true);
                          timelineScrollRef.current?.scrollTo({ x: x - SCREEN_WIDTH / 2, animated: true });
                          const time = (x / TIMELINE_WIDTH) * duration;
                          const clampedTime = Math.max(trimStart, Math.min(trimEnd, time));
                          setCurrentTimeMs(clampedTime);
                          throttledSeek(clampedTime);
                        }}
                      >
                        {thumbnails.map((uri, idx) => (
                          <Image key={idx} source={{ uri }} style={styles.filmstripImage} />
                        ))}
                        <View ref={leftOverlayRef} style={[styles.timelineOverlay, { left: 0, width: startX.current }]} />
                        <View ref={rightOverlayRef} style={[styles.timelineOverlay, { left: endX.current, right: 0 }]} />
                        <View
                          ref={selectionRangeRef}
                          style={[
                            styles.selectionRange,
                            { left: startX.current, width: endX.current - startX.current }
                          ]}
                          {...middlePan.panHandlers}
                        />
                      </Pressable>
                      <View
                        ref={leftHandleRef}
                        style={[
                          styles.customHandle,
                          styles.customHandleLeft,
                          { left: startX.current - 16 }
                        ]}
                        {...startPan.panHandlers}
                      >
                        <View style={styles.handleBarLine} />
                      </View>
                      <View
                        ref={rightHandleRef}
                        style={[
                          styles.customHandle,
                          styles.customHandleRight,
                          { left: endX.current - 16 }
                        ]}
                        {...endPan.panHandlers}
                      >
                        <View style={styles.handleBarLine} />
                      </View>
                    </View>

                    {/* Sub-track 1: Add Audio */}
                    {resolvedMusicList.length > 0 && (
                      <Pressable style={styles.subTrackRow} onPress={() => setShowMusicModal(true)}>
                        <Text style={styles.subTrackIcon}>+</Text>
                        <Text style={styles.subTrackText}>
                          {selectedMusic ? `Audio: ${selectedMusic.title}` : 'Add audio'}
                        </Text>
                      </Pressable>
                    )}

                    {/* Sub-track 2: Add Text */}
                    <Pressable style={styles.subTrackRow} onPress={addTextOverlay}>
                      <Text style={styles.subTrackIcon}>+</Text>
                      <Text style={styles.subTrackText}>
                        {overlays.length > 0 ? `Text overlays (${overlays.length})` : 'Add text'}
                      </Text>
                    </Pressable>
                  </View>
                </View>
              </ScrollView>

              {/* Fixed Playhead indicator in the center */}
              <View style={styles.timelineCenterLine} pointerEvents="none" />

              <Text style={styles.timelineHintText}>
                Tap on a track to seek.
              </Text>
            </View>

            {/* Inline Panel Section — shows when filter/overlay/edit/transform is selected */}
            {(panel === 'filter' || panel === 'frame' || panel === 'edit' || panel === 'transform') && (
              <View style={{ backgroundColor: '#111', maxHeight: 130, borderTopWidth: 1, borderTopColor: '#222' }}>
                {panel === 'filter' && (
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 12, paddingVertical: 10, gap: 10 }}>
                    {['none', 'vivid', 'cool', 'warm', 'fade', 'mono', 'noir', 'chrome'].map((f) => (
                      <Pressable key={f} onPress={() => applyFilterPreset(f)} style={{ alignItems: 'center', gap: 4 }}>
                        <View style={{
                          width: 56, height: 56, borderRadius: 10, backgroundColor: '#222',
                          borderWidth: activeFilter === f ? 2 : 0, borderColor: '#38bdf8',
                          justifyContent: 'center', alignItems: 'center'
                        }}>
                          <Text style={{ fontSize: 20 }}>
                            {f === 'none' ? '○' : f === 'vivid' ? '🌈' : f === 'cool' ? '❄️' : f === 'warm' ? '🔥' : f === 'fade' ? '🌫️' : f === 'mono' ? '⬛' : f === 'noir' ? '🖤' : '📷'}
                          </Text>
                        </View>
                        <Text style={{ color: activeFilter === f ? '#38bdf8' : '#aaa', fontSize: 10, textTransform: 'capitalize' }}>{f}</Text>
                      </Pressable>
                    ))}
                  </ScrollView>
                )}
                {panel === 'edit' && (
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 12, paddingVertical: 8 }}>
                    <AdjustItem label="Brightness" value={imageOptions.brightness ?? 0} onAdjust={(v) => adjustImage({ brightness: v })} min={-1} max={1} />
                    <AdjustItem label="Contrast" value={imageOptions.contrast ?? 1} onAdjust={(v) => adjustImage({ contrast: v })} min={0} max={2} />
                    <AdjustItem label="Saturation" value={imageOptions.saturation ?? 1} onAdjust={(v) => adjustImage({ saturation: v })} min={0} max={2} />
                  </ScrollView>
                )}
                {panel === 'transform' && (
                  <View style={styles.panelInner}>
                    <Text style={styles.panelTitle}>Aspect Ratio</Text>
                    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 12, paddingVertical: 8, gap: 16 }}>
                      {[
                        { label: 'Original', ratio: null },
                        { label: 'Square 1:1', ratio: 1 },
                        { label: 'Portrait 4:5', ratio: 4 / 5 },
                        { label: 'Stories 9:16', ratio: 9 / 16 },
                        { label: 'Landscape 16:9', ratio: 16 / 9 },
                      ].map((r) => {
                        const isSelected = cropRatio === r.ratio;
                        return (
                          <Pressable
                            key={r.label}
                            onPress={() => handleSetRatio(r.ratio)}
                            style={{
                              alignItems: 'center',
                              justifyContent: 'center',
                              paddingHorizontal: 12,
                              paddingVertical: 6,
                              borderRadius: 8,
                              backgroundColor: isSelected ? '#38bdf8' : '#222',
                              borderWidth: 1,
                              borderColor: isSelected ? '#38bdf8' : '#333',
                            }}
                          >
                            <Text style={{ color: isSelected ? '#000' : '#fff', fontSize: 12, fontWeight: '600' }}>
                              {r.label}
                            </Text>
                          </Pressable>
                        );
                      })}
                    </ScrollView>
                    <Text style={{ color: '#888', fontSize: 11, textAlign: 'center', marginBottom: 4 }}>
                      Pinch to zoom and drag to position the video
                    </Text>
                  </View>
                )}
                {panel === 'frame' && (
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 12, paddingVertical: 10, gap: 12 }}>
                    <Pressable
                      style={{ alignItems: 'center', gap: 4 }}
                      onPress={() => adjustImage({ frame: '' })}
                    >
                      <View style={{
                        width: 56, height: 56, borderRadius: 10, backgroundColor: '#333',
                        borderWidth: !imageOptions.frame ? 2 : 0, borderColor: '#38bdf8',
                        justifyContent: 'center', alignItems: 'center'
                      }}>
                        <Ionicons name="close" size={20} color="#fff" />
                      </View>
                      <Text style={{ color: !imageOptions.frame ? '#38bdf8' : '#aaa', fontSize: 10 }}>None</Text>
                    </Pressable>
                    {FRAME_LIST.map((f) => {
                      const isActive = imageOptions.frame === f.key;
                      return (
                        <Pressable key={f.key} onPress={() => adjustImage({ frame: f.key })} style={{ alignItems: 'center', gap: 4 }}>
                          <View style={{
                            width: 56, height: 56, borderRadius: 10, backgroundColor: '#222',
                            borderWidth: isActive ? 2 : 0, borderColor: '#38bdf8',
                            overflow: 'hidden', justifyContent: 'center', alignItems: 'center'
                          }}>
                            {FRAME_IMAGES[f.key] ? (
                              <Image source={FRAME_IMAGES[f.key]} style={{ width: '100%', height: '100%' }} resizeMode="stretch" />
                            ) : (
                              <Text style={{ fontSize: 22 }}>🖼️</Text>
                            )}
                          </View>
                          <Text style={{ color: isActive ? '#38bdf8' : '#aaa', fontSize: 10 }}>{f.label}</Text>
                        </Pressable>
                      );
                    })}
                  </ScrollView>
                )}
              </View>
            )}

            {/* Bottom Toolbar — 6 working tools */}
            <View style={styles.bottomToolBarContainer}>
              <ScrollView
                horizontal
                showsHorizontalScrollIndicator={false}
                style={{ flexGrow: 0 }}
                contentContainerStyle={[styles.toolButtonsRow, { flexGrow: 1, backgroundColor: '#000', paddingVertical: 12 }]}
              >
                <Pressable style={styles.toolButton} onPress={addTextOverlay}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="text" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Text</Text>
                </Pressable>
                {resolvedMusicList.length > 0 && (
                  <Pressable style={[styles.toolButton, showMusicModal && styles.toolButtonActive]} onPress={() => setShowMusicModal(true)}>
                    <View style={styles.toolIconContainer}>
                      <Ionicons name="musical-notes" size={22} color="#fff" />
                    </View>
                    <Text style={styles.toolLabel}>Audio</Text>
                  </Pressable>
                )}
                <Pressable style={[styles.toolButton, panel === 'transform' && styles.toolButtonActive]} onPress={() => setPanel(panel === 'transform' ? 'trim' : 'transform')}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="crop" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Crop</Text>
                </Pressable>
                <Pressable style={[styles.toolButton, panel === 'filter' && styles.toolButtonActive]} onPress={() => setPanel(panel === 'filter' ? 'trim' : 'filter')}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="color-palette" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Filter</Text>
                </Pressable>
                <Pressable style={[styles.toolButton, panel === 'frame' && styles.toolButtonActive]} onPress={() => setPanel(panel === 'frame' ? 'trim' : 'frame')}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="images" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Overlay</Text>
                </Pressable>
                <Pressable style={[styles.toolButton, panel === 'edit' && styles.toolButtonActive]} onPress={() => setPanel(panel === 'edit' ? 'trim' : 'edit')}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="settings-outline" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Edit</Text>
                </Pressable>
              </ScrollView>
            </View>
          </View>
        ) : (
          /* Render Preview Mode UI (Screenshot 1) */
          <View style={[styles.fullPreviewContainer, { justifyContent: 'center', alignItems: 'center' }]}>
            {/* Floating Close Button */}
            <Pressable onPress={onBack} style={styles.fullscreenCloseBtn}>
              <Ionicons name="close" size={24} color="#fff" />
            </Pressable>

            {/* Floating Sound Toggle */}
            <Pressable onPress={() => setIsMuted(!isMuted)} style={styles.fullscreenSoundBtn}>
              <Ionicons name={isMuted ? 'volume-mute' : 'volume-high'} size={22} color="#fff" />
            </Pressable>
            <View
              style={{
                width: '100%',
                aspectRatio: videoAspect || 1,
                maxHeight: '100%',
                justifyContent: 'center',
                alignItems: 'center',
                overflow: 'hidden',
                backgroundColor: '#000',
              }}
            >
              {/* Fullscreen Video */}
              <VideoPreview
                uri={item.uri}
                paused={videoPaused}
                muted={isMuted}
                style={[
                  styles.fullVideo,
                  {
                    position: 'relative',
                    width: '100%',
                    height: '100%',
                    transform: [
                      { scale: zoomScale },
                      { translateX: cropOffset.x },
                      { translateY: cropOffset.y }
                    ]
                  }
                ]}
                resizeMode={cropRatio ? "cover" : "contain"}
                trimStartMs={trimStart}
                trimEndMs={trimEnd}
                seekToMs={seekToMs}
                onChange={(e) => {
                  setCurrentTimeMs(e.nativeEvent.currentTimeMs);
                }}
              />

              {/* Text Overlays */}
              {overlays.map((overlay) => {
                const responder = getTextResponder(overlay.id);
                const isSelected = editingTextId === overlay.id;
                return (
                  <View
                    key={overlay.id}
                    style={[
                      styles.textOverlayContainer,
                      { left: overlay.x, top: overlay.y, zIndex: 20 },
                      isSelected && styles.selectedTextContainer
                    ]}
                    {...responder.panHandlers}
                  >
                    <View style={{ padding: 4 }}>
                      <Text style={[styles.textOverlay, { color: overlay.color, fontSize: overlay.fontSize }]}>
                        {overlay.text}
                      </Text>
                    </View>
                  </View>
                );
              })}
            </View>

            {/* Fullscreen Bottom Overlay Container */}
            <View style={styles.fullscreenBottomContainer}>
              {/* Bottom Toolbar */}
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={[styles.toolButtonsRow, { flexGrow: 1 }]}>
                {resolvedMusicList.length > 0 && (
                  <Pressable style={[styles.toolButton, showMusicModal && styles.toolButtonActive]} onPress={() => setShowMusicModal(true)}>
                    <View style={styles.toolIconContainer}>
                      <Ionicons name="musical-notes" size={22} color="#fff" />
                    </View>
                    <Text style={styles.toolLabel}>Audio</Text>
                  </Pressable>
                )}
                <Pressable style={styles.toolButton} onPress={addTextOverlay}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="text" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Text</Text>
                </Pressable>
                <Pressable style={[styles.toolButton, panel === 'transform' && styles.toolButtonActive]} onPress={() => { setIsEditingVideo(true); setPanel('transform'); }}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="crop" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Crop</Text>
                </Pressable>
                <Pressable style={[styles.toolButton, styles.toolButtonActive]} onPress={() => setIsEditingVideo(true)}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="cut" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Trim</Text>
                </Pressable>
                <Pressable style={[styles.toolButton, panel === 'frame' && styles.toolButtonActive]} onPress={() => { setIsEditingVideo(true); setPanel('frame'); }}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="images" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Overlay</Text>
                </Pressable>
                <Pressable style={[styles.toolButton, panel === 'filter' && styles.toolButtonActive]} onPress={() => { setIsEditingVideo(true); setPanel('filter'); }}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="color-palette" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Filter</Text>
                </Pressable>
                <Pressable style={[styles.toolButton, panel === 'edit' && styles.toolButtonActive]} onPress={() => { setIsEditingVideo(true); setPanel('edit'); }}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="settings-outline" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Edit</Text>
                </Pressable>
              </ScrollView>

              {/* Action Row: Edit video & Next */}
              <View style={styles.fullscreenActionRow}>
                <Pressable style={styles.editVideoBtn} onPress={() => setIsEditingVideo(true)}>
                  <Text style={styles.editVideoText}>Edit video</Text>
                </Pressable>
                <Pressable style={styles.nextPillBtn} onPress={handleSaveAll} disabled={saving}>
                  {saving ? (
                    <ActivityIndicator size="small" color="#fff" />
                  ) : (
                    <Text style={styles.nextPillText}>Next ➔</Text>
                  )}
                </Pressable>
              </View>
            </View>
          </View>
        )
      ) : (
        <>
          {/* Modern Header */}
          <View style={styles.header}>
            <Pressable onPress={onBack} style={styles.backButton}>
              <Ionicons name="close" size={22} color="#fff" />
            </Pressable>
            <View style={styles.headerRight}>
              <Pressable onPress={() => setIsMuted(!isMuted)} style={styles.soundButton}>
                <Ionicons name={isMuted ? 'volume-mute' : 'volume-high'} size={22} color="#fff" />
              </Pressable>
            </View>
          </View>

          <View style={styles.content}>
            <View style={{ height: carouselHeight, marginVertical: 12 }}>
              <FlatList
                ref={flatListRef}
                data={items}
                extraData={[
                  overlays,
                  editingTextId,
                  editsHistory,
                  activeFilter,
                  imageOptions,
                  trimStart,
                  trimEnd,
                  isMuted,
                  activeIndex,
                ]}
                keyExtractor={(it) => it.id}
                initialScrollIndex={activeIndex}
                getItemLayout={(_, index) => ({
                  length: SNAP_INTERVAL,
                  offset: SNAP_INTERVAL * index,
                  index,
                })}
                horizontal
                pagingEnabled={false}
                showsHorizontalScrollIndicator={false}
                snapToInterval={SNAP_INTERVAL}
                decelerationRate="fast"
                contentContainerStyle={{
                  paddingHorizontal: (SCREEN_WIDTH - CARD_WIDTH) / 2 - CARD_MARGIN,
                  alignItems: 'center',
                }}
                onMomentumScrollEnd={handleScrollEnd}
                renderItem={renderCard}
              />
            </View>

            {selectedMusic && (
              <Pressable
                onPress={() => setShowMusicModal(true)}
                style={styles.floatingMusicBadge}
              >
                <Text style={styles.floatingMusicBadgeText}>🎵 {selectedMusic.title} - {selectedMusic.artist}</Text>
              </Pressable>
            )}

            <View style={styles.editorPanel}>
              {panel === 'filter' && (
                <View style={styles.panelInner}>
                  <Text style={styles.panelTitle}>Filters</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.filterScroll}>
                    {Object.keys(FILTERS).map((key) => {
                      const f = (FILTERS as any)[key];
                      return (
                        <Pressable
                          key={key}
                          style={[styles.filterThumb, activeFilter === key && styles.filterThumbActive]}
                          onPress={() => applyFilterPreset(key)}
                        >
                          <View style={styles.filterPreviewContainer}>
                            <Image
                              source={{ uri: item.uri }}
                              style={styles.filterPreview}
                              resizeMode="cover"
                            />
                            <View
                              style={[
                                StyleSheet.absoluteFill,
                                {
                                  backgroundColor: getPreviewOverlayColor(key),
                                  opacity: getPreviewOverlayOpacity(key),
                                },
                              ]}
                            />
                          </View>
                          <Text style={[styles.filterLabel, activeFilter === key && styles.filterLabelActive]}>
                            {f.label}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </ScrollView>
                </View>
              )}

              {panel === 'edit' && (
                <View style={styles.panelInner}>
                  <Text style={styles.panelTitle}>Adjustments</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 12 }}>
                    <AdjustItem label="Brightness" value={imageOptions.brightness ?? 0} onAdjust={(v) => adjustImage({ brightness: v })} min={-1} max={1} />
                    <AdjustItem label="Contrast" value={imageOptions.contrast ?? 1} onAdjust={(v) => adjustImage({ contrast: v })} min={0} max={2} />
                    <AdjustItem label="Saturation" value={imageOptions.saturation ?? 1} onAdjust={(v) => adjustImage({ saturation: v })} min={0} max={2} />
                  </ScrollView>
                </View>
              )}

              {panel === 'trim' && item.type === 'video' && (
                <View style={styles.panelInner}>
                  <Text style={styles.panelTitle}>Trim Video</Text>
                  <View style={{ alignItems: 'center', marginBottom: 6 }}>
                    <Text style={{ color: '#fff', fontSize: 13, fontWeight: '700' }}>
                      {(() => {
                        const selMs = ((endX.current - startX.current) / TIMELINE_WIDTH) * duration;
                        const totalSec = Math.floor(selMs / 1000);
                        return totalSec >= 60
                          ? `${Math.floor(totalSec / 60)}:${(totalSec % 60).toString().padStart(2, '0')} selected`
                          : `${(selMs / 1000).toFixed(1)}s selected`;
                      })()}
                    </Text>
                  </View>
                  <View style={[styles.trimTimelineBox, { overflow: 'visible' }]}>
                    <View style={styles.filmstrip}>
                      {thumbnails.length === 0 ? (
                        <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
                          <ActivityIndicator color="#ffffff" size="small" />
                        </View>
                      ) : (
                        thumbnails.map((uri, idx) => (
                          <Image key={idx} source={{ uri }} style={styles.filmstripImage} />
                        ))
                      )}
                      <View ref={leftOverlayRef} style={[styles.timelineOverlay, { left: 0, width: startX.current }]} />
                      <View ref={rightOverlayRef} style={[styles.timelineOverlay, { left: endX.current, right: 0 }]} />
                      <View
                        ref={selectionRangeRef}
                        style={[
                          styles.selectionRange,
                          { left: startX.current, width: endX.current - startX.current }
                        ]}
                        {...middlePan.panHandlers}
                      />
                    </View>
                    <View
                      ref={leftHandleRef}
                      style={[
                        styles.customHandle,
                        styles.customHandleLeft,
                        { left: startX.current - 16 }
                      ]}
                      {...startPan.panHandlers}
                    >
                      <View style={styles.handleBarLine} />
                    </View>
                    <View
                      ref={rightHandleRef}
                      style={[
                        styles.customHandle,
                        styles.customHandleRight,
                        { left: endX.current - 16 }
                      ]}
                      {...endPan.panHandlers}
                    >
                      <View style={styles.handleBarLine} />
                    </View>
                  </View>
                </View>
              )}

              {panel === 'frame' && (
                <View style={styles.panelInner}>
                  <Text style={styles.panelTitle}>Overlays & Frames</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                    <Pressable
                      style={[styles.filterThumb, !imageOptions.frame && styles.filterThumbActive]}
                      onPress={() => adjustImage({ frame: undefined })}
                    >
                      <View style={[styles.filterPreviewContainer, { backgroundColor: '#333', justifyContent: 'center', alignItems: 'center' }]}>
                        <Ionicons name="close" size={24} color="#fff" />
                      </View>
                      <Text style={[styles.filterLabel, !imageOptions.frame && styles.filterLabelActive]}>None</Text>
                    </Pressable>
                    {FRAME_LIST.map((f) => {
                      const isActive = imageOptions.frame === f.key;
                      return (
                        <Pressable
                          key={f.key}
                          style={[styles.filterThumb, isActive && styles.filterThumbActive]}
                          onPress={() => adjustImage({ frame: f.key })}
                        >
                          <View style={styles.filterPreviewContainer}>
                            {FRAME_IMAGES[f.key] ? (
                              <Image source={FRAME_IMAGES[f.key]} style={{ width: '100%', height: '100%', backgroundColor: '#222' }} resizeMode="stretch" />
                            ) : (
                              <View style={{ width: '100%', height: '100%', backgroundColor: '#222' }} />
                            )}
                          </View>
                          <Text style={[styles.filterLabel, isActive && styles.filterLabelActive]}>{f.label}</Text>
                        </Pressable>
                      );
                    })}
                  </ScrollView>
                </View>
              )}

              {panel === 'text' && (
                <View style={[styles.panelInner, { alignItems: 'center', paddingVertical: 12 }]}>
                  <Pressable style={styles.addTextPill} onPress={addTextOverlay}>
                    <Text style={styles.addTextPillText}>➕ Add Text Box</Text>
                  </Pressable>
                </View>
              )}

              {/* ── STICKERS PANEL ────────────────────────────────────────────── */}
              {panel === 'sticker' && (
                <View style={styles.panelInner}>
                  <Text style={styles.panelTitle}>Stickers</Text>
                  <ScrollView horizontal={false} style={{ maxHeight: 140 }} showsVerticalScrollIndicator={false}>
                    <View style={{ flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 8 }}>
                      {STICKER_LIST.map((emoji, idx) => (
                        <Pressable
                          key={idx}
                          onPress={() => addSticker(emoji)}
                          style={styles.stickerBtn}
                        >
                          <Text style={styles.stickerEmoji}>{emoji}</Text>
                        </Pressable>
                      ))}
                    </View>
                  </ScrollView>
                  {stickers.length > 0 && (
                    <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 8, paddingHorizontal: 8 }}>
                      <Text style={{ color: '#94a3b8', fontSize: 11, width: '100%', marginBottom: 4 }}>Added — tap to remove:</Text>
                      {stickers.map(s => (
                        <Pressable key={s.id} onPress={() => removeSticker(s.id)} style={styles.addedStickerChip}>
                          <Text style={{ fontSize: 20 }}>{s.emoji}</Text>
                          <Ionicons name="close-circle" size={14} color="#ff6b6b" style={{ marginLeft: 4 }} />
                        </Pressable>
                      ))}
                    </View>
                  )}
                </View>
              )}

              {/* ── EFFECTS PANEL ─────────────────────────────────────────────── */}
              {panel === 'effects' && (
                <View style={styles.panelInner}>
                  <Text style={styles.panelTitle}>Effects</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                    {EFFECTS_LIST.map(eff => (
                      <Pressable
                        key={eff.id}
                        style={[styles.effectThumb, activeEffect === eff.id && styles.effectThumbActive]}
                        onPress={() => {
                          pushToHistory();
                          setActiveEffect(eff.id);
                        }}
                      >
                        <View style={[
                          styles.effectIconBox,
                          activeEffect === eff.id && { borderColor: '#3b82f6', backgroundColor: 'rgba(59,130,246,0.2)' }
                        ]}>
                          <Text style={{ fontSize: 26 }}>{eff.icon}</Text>
                        </View>
                        <Text style={[styles.filterLabel, activeEffect === eff.id && styles.filterLabelActive]}>
                          {eff.label}
                        </Text>
                      </Pressable>
                    ))}
                  </ScrollView>
                </View>
              )}

              {/* ── CAPTION PANEL ─────────────────────────────────────────────── */}
              {panel === 'caption' && (
                <View style={styles.panelInner}>
                  <Text style={styles.panelTitle}>Caption</Text>
                  {/* Style picker */}
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 8 }}>
                    {CAPTION_STYLES.map(cs => (
                      <Pressable
                        key={cs.id}
                        style={[styles.captionStylePill, captionStyle === cs.id && styles.captionStylePillActive]}
                        onPress={() => setCaptionStyle(cs.id)}
                      >
                        <Text style={[{ fontSize: 12, fontWeight: cs.fontWeight }, { color: captionStyle === cs.id ? '#fff' : '#94a3b8' }]}>
                          {cs.label}
                        </Text>
                      </Pressable>
                    ))}
                  </ScrollView>
                  {/* Input row */}
                  <View style={styles.captionInputRow}>
                    <TextInput
                      style={styles.captionInput}
                      value={captionInput}
                      onChangeText={setCaptionInput}
                      placeholder="Type caption..."
                      placeholderTextColor="#64748b"
                      returnKeyType="done"
                      onSubmitEditing={addCaption}
                    />
                    <Pressable style={styles.captionAddBtn} onPress={addCaption}>
                      <Text style={{ color: '#fff', fontWeight: '700' }}>Add</Text>
                    </Pressable>
                  </View>
                  {/* Added captions list */}
                  {captions.length > 0 && (
                    <View style={{ marginTop: 8 }}>
                      {captions.map(c => {
                        const cs = CAPTION_STYLES.find(s => s.id === c.style) || CAPTION_STYLES[0];
                        return (
                          <View key={c.id} style={styles.captionListItem}>
                            <View style={[styles.captionPreviewChip, { backgroundColor: cs.bg }]}>
                              <Text style={[styles.captionPreviewText, { color: cs.color, fontWeight: cs.fontWeight }]}>
                                {c.text}
                              </Text>
                            </View>
                            <Pressable onPress={() => removeCaption(c.id)} style={styles.captionRemoveBtn}>
                              <Ionicons name="close" size={14} color="#ff6b6b" />
                            </Pressable>
                          </View>
                        );
                      })}
                    </View>
                  )}
                </View>
              )}

              {/* ── ADD CLIP PANEL ────────────────────────────────────────────── */}
              {panel === 'addclip' && (
                <View style={[styles.panelInner, { alignItems: 'center', justifyContent: 'center', paddingVertical: 18 }]}>
                  <Pressable style={styles.addClipBigBtn} onPress={() => Alert.alert('Add Clip', 'Clip picker coming soon. You can select another video to append to the timeline.')}>
                    <Text style={{ fontSize: 32, marginBottom: 6 }}>➕</Text>
                    <Text style={styles.addClipBigText}>Add Clip</Text>
                    <Text style={styles.addClipSubText}>Tap to pick another video</Text>
                  </Pressable>
                </View>
              )}
            </View>

            {/* Tools row and bottom navigation controls */}
            <View style={styles.bottomToolBarContainer}>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={[styles.toolButtonsRow, { flexGrow: 1 }]}>
                {resolvedMusicList.length > 0 && (
                  <Pressable style={[styles.toolButton, showMusicModal && styles.toolButtonActive]} onPress={() => setShowMusicModal(true)}>
                    <View style={styles.toolIconContainer}>
                      <Ionicons name="musical-notes" size={22} color="#fff" />
                    </View>
                    <Text style={styles.toolLabel}>Audio</Text>
                  </Pressable>
                )}
                <Pressable style={[styles.toolButton, panel === 'text' && styles.toolButtonActive]} onPress={() => setPanel('text')}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="text" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Text</Text>
                </Pressable>
                {item.type === 'image' ? (
                  <Pressable style={[styles.toolButton]} onPress={handleOpenTransform}>
                    <View style={styles.toolIconContainer}>
                      <Ionicons name="crop" size={22} color="#fff" />
                    </View>
                    <Text style={styles.toolLabel}>Crop</Text>
                  </Pressable>
                ) : (
                  <Pressable style={[styles.toolButton, panel === 'trim' && styles.toolButtonActive]} onPress={() => setPanel('trim')}>
                    <View style={styles.toolIconContainer}>
                      <Ionicons name="cut" size={22} color="#fff" />
                    </View>
                    <Text style={styles.toolLabel}>Trim</Text>
                  </Pressable>
                )}
                <Pressable style={[styles.toolButton, panel === 'frame' && styles.toolButtonActive]} onPress={() => setPanel('frame')}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="images" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Overlay</Text>
                </Pressable>
                <Pressable style={[styles.toolButton, panel === 'filter' && styles.toolButtonActive]} onPress={() => setPanel('filter')}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="color-palette" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Filter</Text>
                </Pressable>
                <Pressable style={[styles.toolButton, panel === 'edit' && styles.toolButtonActive]} onPress={() => setPanel('edit')}>
                  <View style={styles.toolIconContainer}>
                    <Ionicons name="settings-outline" size={22} color="#fff" />
                  </View>
                  <Text style={styles.toolLabel}>Edit</Text>
                </Pressable>
              </ScrollView>

              <View style={styles.bottomNavButtonsRow}>
                <Pressable style={styles.nextBlueBtn} onPress={handleSaveAll} disabled={saving}>
                  {saving ? (
                    <ActivityIndicator size="small" color="#fff" />
                  ) : (
                    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                      <Text style={styles.nextBlueText}>Next</Text>
                      <Ionicons name="arrow-forward" size={16} color="#fff" style={{ marginLeft: 4 }} />
                    </View>
                  )}
                </Pressable>
              </View>
            </View>
          </View>
        </>
      )}

      <Modal
        visible={showMusicModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowMusicModal(false)}
      >
        <Pressable style={styles.musicModalOverlay} onPress={() => setShowMusicModal(false)}>
          <View style={styles.musicModalContent} onStartShouldSetResponder={() => true} onTouchEnd={(e) => e.stopPropagation()}>
            {/* Top Handle Bar */}
            <View style={styles.musicModalHandle} />

            {/* Header */}
            <View style={styles.musicModalHeader}>
              <Text style={styles.musicModalTitle}>Select Music</Text>
              <Pressable onPress={() => setShowMusicModal(false)} style={styles.musicModalCloseBtn}>
                <Ionicons name="close" size={24} color="#fff" />
              </Pressable>
            </View>

            {/* Search Input */}
            <View style={styles.musicSearchContainer}>
              <Text style={styles.musicSearchIcon}>🔍</Text>
              <TextInput
                style={styles.musicSearchInput}
                value={musicSearchQuery}
                onChangeText={setMusicSearchQuery}
                placeholder="Search..."
                placeholderTextColor="#8e8e93"
                autoCapitalize="none"
              />
              {musicSearchQuery.length > 0 && (
                <Pressable onPress={() => setMusicSearchQuery('')} style={styles.musicSearchClearBtn}>
                  <Ionicons name="close-circle" size={18} color="#8e8e93" />
                </Pressable>
              )}
            </View>

            {/* Tabs */}
            <View style={styles.musicTabsContainer}>
              <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                {[
                  { id: 'for_you', label: 'For you' },
                  { id: 'trending', label: 'Trending' },
                  { id: 'saved', label: 'Saved' },
                  { id: 'original', label: 'Original audio' },
                  { id: 'custom', label: 'Custom music' }
                ].map((tab) => {
                  const isActive = activeMusicTab === tab.id;
                  return (
                    <Pressable
                      key={tab.id}
                      onPress={() => setActiveMusicTab(tab.id as any)}
                      style={[styles.musicTabPill, isActive && styles.musicTabPillActive]}
                    >
                      <Text style={[styles.musicTabLabel, isActive && styles.musicTabLabelActive]}>
                        {tab.label}
                      </Text>
                    </Pressable>
                  );
                })}
              </ScrollView>
            </View>

            {/* Music List */}
            <FlatList
              data={filteredMusicList}
              keyExtractor={(item) => item.id}
              showsVerticalScrollIndicator={false}
              contentContainerStyle={{ paddingBottom: 40 }}
              renderItem={({ item: track, index }) => {
                const isSelected = selectedMusic?.id === track.id;
                const startIndex = activeMusicTab === 'trending' ? 14 : 1;
                return (
                  <Pressable
                    onPress={() => {
                      if (isSelected) {
                        setMusicPaused(!musicPaused);
                      } else {
                        setSelectedMusic(track);
                        setMusicPaused(false);
                        // Auto-mute video audio when music is selected
                        setIsMuted(true);
                      }
                    }}
                    style={[styles.musicRow, isSelected && styles.musicRowSelected]}
                  >
                    <Text style={styles.musicRowIndex}>{index + startIndex}</Text>
                    <Image source={{ uri: track.cover }} style={styles.musicRowCover} />
                    <View style={styles.musicRowInfo}>
                      <Text style={styles.musicRowTitle} numberOfLines={1}>
                        {track.title}
                      </Text>
                      <Text style={styles.musicRowArtist} numberOfLines={1}>
                        {track.artist} • {track.duration}
                      </Text>
                    </View>
                    {isSelected && (
                      <View style={styles.musicPlayingIndicator}>
                        <Text style={{ fontSize: 11, color: '#38bdf8', marginRight: 12, fontWeight: '700' }}>
                          {musicPaused ? 'PAUSED' : 'PLAYING'}
                        </Text>
                      </View>
                    )}
                    <Pressable style={styles.musicSaveBtn}>
                      <Text style={styles.musicSaveIcon}>🔖</Text>
                    </Pressable>
                  </Pressable>
                );
              }}
              ListEmptyComponent={
                <View style={styles.musicListEmpty}>
                  <Text style={styles.musicListEmptyText}>No music tracks found</Text>
                </View>
              }
            />

            {/* Selected Music Footer */}
            {selectedMusic && (
              <View style={styles.musicModalFooter}>
                <View style={styles.musicFooterLeft}>
                  <Image source={{ uri: selectedMusic.cover }} style={styles.musicFooterCover} />
                  <View style={{ flex: 1 }}>
                    <Text style={styles.musicFooterTitle} numberOfLines={1}>
                      {selectedMusic.title}
                    </Text>
                    <Text style={styles.musicFooterArtist} numberOfLines={1}>
                      {selectedMusic.artist}
                    </Text>
                  </View>
                </View>
                <Pressable
                  onPress={() => {
                    setSelectedMusic(null);
                    setMusicPaused(true);
                    setIsMuted(false);
                  }}
                  style={styles.musicFooterRemoveBtn}
                >
                  <Text style={styles.musicFooterRemoveText}>Remove</Text>
                </Pressable>
              </View>
            )}
          </View>
        </Pressable>
      </Modal>

      <Modal visible={!!editingTextId} transparent animationType="fade">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.controlSubTitle}>ADD TEXT</Text>
            <TextInput
              style={[
                styles.modalInput,
                { color: overlays.find(o => o.id === editingTextId)?.color || '#FFFFFF' }
              ]}
              value={newText}
              onChangeText={(txt) => {
                setNewText(txt);
                if (editingTextId) {
                  updateTextOverlay(editingTextId, { text: txt });
                }
              }}
              autoFocus
              placeholder="Type something..."
              placeholderTextColor="#555"
            />

            <View style={styles.modalColorPicker}>
              <Text style={styles.controlSubTitle}>Pick Color</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 4 }}>
                {[
                  '#FFFFFF', '#000000', '#FF3B30', '#FF9500', '#FFCC00',
                  '#4CD964', '#5AC8FA', '#007AFF', '#5856D6', '#FF2D55',
                  '#A2845E', '#E5E5EA', '#8E8E93', '#3A3A3C'
                ].map(c => (
                  <Pressable
                    key={c}
                    onPress={() => updateTextOverlay(editingTextId!, { color: c })}
                    style={[styles.colorOption, { backgroundColor: c }, overlays.find(o => o.id === editingTextId)?.color === c && styles.colorOptionActive]}
                  />
                ))}
              </ScrollView>
            </View>

            <View style={styles.modalActions}>
              <Pressable
                onPress={() => {
                  if (editingTextId) {
                    if (isNewOverlay.current) {
                      setUndoStack(prev => prev.slice(0, prev.length - 1));
                      setOverlays(prev => prev.filter(o => o.id !== editingTextId));
                    } else if (originalOverlayBackup.current) {
                      setUndoStack(prev => prev.slice(0, prev.length - 1));
                      setOverlays(prev => prev.map(o => o.id === editingTextId ? { ...o, ...originalOverlayBackup.current } : o));
                    }
                  }
                  isNewOverlay.current = false;
                  originalOverlayBackup.current = null;
                  setEditingTextId(null);
                  setNewText('');
                }}
                style={styles.modalBtn}
              >
                <Text style={styles.modalBtnText}>Cancel</Text>
              </Pressable>
              <Pressable
                onPress={() => {
                  if (editingTextId) {
                    if (!newText.trim()) {
                      setOverlays(prev => prev.filter(o => o.id !== editingTextId));
                    } else {
                      setOverlays(prev => prev.map(o => o.id === editingTextId ? { ...o, text: newText.trim() } : o));
                    }
                  }
                  isNewOverlay.current = false;
                  originalOverlayBackup.current = null;
                  setEditingTextId(null);
                  setNewText('');
                }}
                style={[styles.modalBtn, styles.modalBtnPrimary]}
              >
                <Text style={styles.modalBtnTextPrimary}>Done</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      {/* Global Trash Zone for Drag Delete */}
      {activeDraggingId !== null && (
        <View style={styles.globalTrashZone} pointerEvents="none">
          <View
            style={[
              styles.trashZoneContainer,
              isOverTrash && styles.trashZoneActive,
              isOverTrash ? { transform: [{ scale: 1.15 }] } : {}
            ]}
          >
            <Ionicons name={isOverTrash ? "trash" : "trash-outline"} size={20} color="#fff" />
            <Text style={styles.trashZoneText}>
              {isOverTrash ? "Release to Delete" : "Drag here to delete"}
            </Text>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000000' },
  fullPreviewContainer: {
    flex: 1,
    backgroundColor: '#000',
  },
  fullVideo: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
  fullscreenCloseBtn: {
    position: 'absolute',
    top: Platform.OS === 'ios' ? 54 : 16,
    left: 16,
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 10,
  },
  fullscreenCloseText: {
    color: '#FFF',
    fontSize: 18,
    fontWeight: '600',
  },
  fullscreenSoundBtn: {
    position: 'absolute',
    top: Platform.OS === 'ios' ? 54 : 16,
    right: 16,
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 10,
  },
  fullscreenSoundText: {
    fontSize: 18,
  },
  fullscreenBottomContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingBottom: 36,
    paddingTop: 20,
    backgroundColor: '#000000',
    zIndex: 10,
  },
  fullscreenActionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    marginTop: 16,
  },
  editVideoBtn: {
    paddingVertical: 12,
    paddingHorizontal: 24,
    borderRadius: 24,
    borderWidth: 1.2,
    borderColor: '#FFF',
    backgroundColor: 'rgba(0,0,0,0.3)',
  },
  editVideoText: {
    color: '#FFF',
    fontSize: 15,
    fontWeight: '700',
  },
  nextPillBtn: {
    paddingVertical: 12,
    paddingHorizontal: 30,
    borderRadius: 24,
    backgroundColor: '#FFFFFF',
  },
  nextPillText: {
    color: '#000',
    fontSize: 15,
    fontWeight: '700',
  },
  editModeContainer: {
    flex: 1,
    backgroundColor: '#000000',
  },
  editModeHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    height: 56,
    marginTop: 12,
  },
  editModeBackBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.15)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  editModeBackText: {
    color: '#FFF',
    fontSize: 20,
    fontWeight: 'bold',
    textAlign: 'center',
    includeFontPadding: false,
    textAlignVertical: 'center',
  },
  editModeNextBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#3b82f6',
    justifyContent: 'center',
    alignItems: 'center',
  },

  editModeNextText: {
    color: '#FFF',
    fontSize: 20,
    fontWeight: 'bold',
    textAlign: 'center',
    includeFontPadding: false, // Android
  },
  editModePlayerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#000',
    position: 'relative',
  },
  editModeVideo: {
    width: '100%',
    height: '100%',
  },
  playerControlsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 10,
    backgroundColor: '#000',
  },
  editPlayPauseBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(255,255,255,0.2)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  playPauseIconText: {
    color: '#FFF',
    fontSize: 16,
  },
  handleText: {
    color: '#FFF',
    fontSize: 12,
    fontWeight: 'bold',
  },
  timelinePlayhead: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    width: 3,
    backgroundColor: '#FF3B30',
    zIndex: 15,
  },
  durationText: {
    color: '#FFF',
    marginLeft: 12,
    fontSize: 13,
    fontWeight: '600',
  },
  historyButtons: {
    flexDirection: 'row',
    marginLeft: 'auto',
  },
  historyBtn: {
    width: 32,
    height: 32,
    justifyContent: 'center',
    alignItems: 'center',
    marginHorizontal: 4,
  },
  historyBtnText: {
    color: '#FFF',
    fontSize: 18,
  },
  timelineSection: {
    backgroundColor: '#111111',
    paddingVertical: 12,
  },
  timelineRuler: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingHorizontal: 0,
    marginBottom: 8,
  },
  timelineRulerDot: {
    width: 2,
    height: 6,
    backgroundColor: '#333333',
  },
  timelineRulerText: {
    color: '#555555',
    fontSize: 10,
  },
  timelineScrollContainer: {
    position: 'relative',
    paddingVertical: 8,
  },
  timelineCenterLine: {
    position: 'absolute',
    left: SCREEN_WIDTH / 2,
    top: 12,
    bottom: 32,
    width: 2,
    backgroundColor: '#FFFFFF',
    zIndex: 100,
  },
  timelineTracksContainer: {
    paddingHorizontal: 0,
  },
  filmstripTrack: {
    height: 60,
    borderRadius: 8,
    overflow: 'hidden',
    backgroundColor: '#222222',
    marginBottom: 12,
  },
  subTrackRow: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 38,
    borderRadius: 6,
    backgroundColor: '#1E1E1E',
    paddingHorizontal: 12,
    marginBottom: 8,
  },
  subTrackIcon: {
    color: '#007AFF',
    fontSize: 16,
    fontWeight: '700',
    marginRight: 8,
  },
  subTrackText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
  },
  timelineHintText: {
    color: '#444444',
    fontSize: 11,
    textAlign: 'center',
    marginTop: 4,
  },
  musicCard: {
    width: 110,
    backgroundColor: '#1E1E1E',
    borderRadius: 8,
    padding: 8,
    marginRight: 12,
    alignItems: 'center',
    borderWidth: 1.5,
    borderColor: 'transparent',
  },
  musicCardActive: {
    borderColor: '#007AFF',
    backgroundColor: '#2A2A2A',
  },
  musicIconContainer: {
    width: 50,
    height: 50,
    borderRadius: 25,
    backgroundColor: '#333',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 8,
  },
  musicIconContainerActive: {
    backgroundColor: '#007AFF',
  },
  musicTitle: {
    color: '#FFF',
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
    width: '100%',
  },
  musicArtist: {
    color: '#AAA',
    fontSize: 10,
    textAlign: 'center',
    marginTop: 2,
    width: '100%',
  },
  musicDuration: {
    color: '#666',
    fontSize: 9,
    marginTop: 4,
  },
  playPauseBtn: {
    marginTop: 6,
    backgroundColor: '#007AFF',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 4,
  },
  header: {
    height: 56,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    borderBottomWidth: 0.5,
    borderBottomColor: '#333',
  },
  headerIcon: { color: '#fff', fontSize: 24 },
  headerLink: { color: '#fff', fontSize: 16, fontWeight: '600' },
  title: { color: '#fff', fontSize: 16, fontWeight: '700' },
  headerRight: { flexDirection: 'row', alignItems: 'center' },
  downloadIcon: { marginRight: 20 },
  content: { flex: 1 },
  previewContainer: {
    height: SCREEN_WIDTH * 1.25,
    backgroundColor: '#111',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 12,
  },
  previewBox: {
    width: '100%',
    height: '100%',
    borderRadius: 12,
    overflow: 'hidden',
    alignSelf: 'center',
  },
  preview: { width: '100%', height: '100%' },
  previewContainerResized: {
    width: '100%',
    height: '100%',
    position: 'absolute',
    top: 0,
    left: 0,
    bottom: 0,
    right: 0
  },
  videoPreview: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#000',
  },
  previewOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
  },
  quickRatioWrap: {
    position: 'absolute',
    left: 12,
    bottom: 12,
    zIndex: 20,
  },
  quickRatioButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: 'rgba(20,24,33,0.95)',
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  quickRatioButtonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  quickRatioMenu: {
    marginBottom: 8,
    backgroundColor: 'rgba(20,24,33,0.96)',
    borderRadius: 14,
    overflow: 'hidden',
    minWidth: 150,
  },
  quickRatioItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 12,
  },
  quickRatioIcon: { color: '#fff', width: 18, fontSize: 16 },
  quickRatioText: { color: '#fff', fontSize: 16, flex: 1, fontWeight: '500' },
  quickRatioCheck: { color: '#fff', fontSize: 18, fontWeight: '700' },
  playPauseCircle: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: 'rgba(0,0,0,0.4)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  playPauseText: { color: '#fff', fontSize: 24, marginLeft: 4 },
  editorPanel: { flex: 1, justifyContent: 'center' },
  panelInner: { paddingHorizontal: 16 },
  panelTitle: { color: '#999', fontSize: 12, fontWeight: '700', marginBottom: 16, textTransform: 'uppercase' },
  bottomNav: {
    height: 80,
    borderTopWidth: 0.5,
    borderTopColor: '#333',
    justifyContent: 'center',
  },
  tabsBar: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingHorizontal: 12,
  },
  trimBottomBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  bottomLinkText: { color: '#fff', fontSize: 16, fontWeight: '500' },
  doneText: { color: '#38bdf8' },
  disabled: { opacity: 0.5 },
  trayButton: {
    paddingVertical: 10,
    paddingHorizontal: 20,
    alignItems: 'center',
  },
  trayButtonActive: { borderBottomWidth: 2, borderBottomColor: '#fff' },
  trayButtonDisabled: { opacity: 0.4 },
  trayButtonText: { color: '#fff', fontWeight: '700', fontSize: 13 },
  filterScroll: { marginTop: 4 },
  filterThumb: {
    width: 80,
    marginRight: 12,
    alignItems: 'center',
  },
  filterThumbActive: { transform: [{ scale: 1.05 }] },
  filterPreviewContainer: {
    width: 70,
    height: 70,
    borderRadius: 8,
    overflow: 'hidden',
    marginBottom: 8,
  },
  filterPreview: { width: '100%', height: '100%' },
  filterLabel: { color: '#999', fontSize: 11, fontWeight: '500' },
  filterLabelActive: { color: '#fff', fontWeight: '700' },

  colorCircle: {
    width: 48,
    height: 48,
    borderRadius: 24,
    marginRight: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  colorCircleActive: {
    transform: [{ scale: 1.1 }],
    borderWidth: 2,
    borderColor: '#fff',
  },

  frameSwatch: {
    alignItems: 'center',
    marginRight: 12,
  },
  frameSwatchBox: {
    width: 52,
    height: 52,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 6,
  },
  frameSwatchBoxActive: {
    borderWidth: 2.5,
    borderColor: '#38bdf8',
  },
  frameSwatchLabel: {
    color: '#666',
    fontSize: 11,
    fontWeight: '500',
  },

  adjustItem: {
    width: 100,
    alignItems: 'center',
    marginRight: 16,
  },
  adjustLabel: { color: '#999', fontSize: 12, marginBottom: 12 },
  adjustCircle: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#111',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#333',
  },
  adjustCircleActive: { borderColor: '#fff' },
  adjustValue: { color: '#fff', fontSize: 10, fontWeight: '700' },
  adjustSmallButton: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#222',
    alignItems: 'center',
    justifyContent: 'center',
    marginHorizontal: 4,
  },
  adjustSmallButtonText: { color: '#fff', fontSize: 14, fontWeight: '700' },
  trimTimelineBox: { width: TIMELINE_WIDTH, alignSelf: 'center', marginTop: 10 },
  filmstrip: {
    width: '100%',
    height: 60,
    flexDirection: 'row',
    backgroundColor: '#111',
    borderRadius: 4,
    overflow: 'hidden',
  },
  filmstripImage: { width: TIMELINE_WIDTH / 10, height: 60 },
  timelineOverlay: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.6)',
  },
  selectionRange: {
    position: 'absolute',
    top: 0,
    height: 60,
    backgroundColor: 'transparent',
    borderTopWidth: 2,
    borderBottomWidth: 2,
    borderColor: '#FFD60A',
  },
  handle: {
    position: 'absolute',
    top: 18,
    width: HANDLE_SIZE,
    height: HANDLE_SIZE,
    borderRadius: HANDLE_SIZE / 2,
    backgroundColor: '#fff',
    zIndex: 10,
    elevation: 5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 2,
  },
  handleLeft: {},
  handleRight: {},
  customHandle: {
    position: 'absolute',
    top: 0,
    width: 16,
    height: 60,
    backgroundColor: '#FFD60A',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 20,
  },
  customHandleLeft: {
    borderTopLeftRadius: 8,
    borderBottomLeftRadius: 8,
  },
  customHandleRight: {
    borderTopRightRadius: 8,
    borderBottomRightRadius: 8,
  },
  handleBarLine: {
    width: 2,
    height: 16,
    backgroundColor: '#333333',
    borderRadius: 1,
  },
  timeMarkers: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 8,
    paddingHorizontal: 2,
  },
  timeCode: { color: '#666', fontSize: 10, fontWeight: '500' },
  row: { flexDirection: 'row', flexWrap: 'wrap', marginBottom: 8 },
  aspectItem: {
    alignItems: 'center',
    marginRight: 20,
    width: 60,
  },
  aspectIconContainer: {
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
  },
  resetIcon: {
    color: '#fff',
    fontSize: 24,
  },
  aspectDashed: {
    width: 32,
    height: 32,
    borderWidth: 1,
    borderColor: '#999',
    borderStyle: 'dashed',
  },
  aspectBox: {
    width: 32,
    backgroundColor: '#666',
  },
  aspectActiveBorder: {
    borderColor: '#fff',
    backgroundColor: 'transparent',
    borderWidth: 2,
  },
  aspectLabel: {
    color: '#999',
    fontSize: 12,
  },
  aspectLabelActive: {
    color: '#fff',
    fontWeight: '700',
  },
  // Transform Tool Styles
  cropOverlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
  },
  gridLineV: {
    position: 'absolute',
    left: '33.3%',
    width: 0.8,
    height: '100%',
    backgroundColor: 'rgba(255,255,255,0.7)',
  },
  gridLineV2: {
    position: 'absolute',
    left: '66.6%',
    width: 0.8,
    height: '100%',
    backgroundColor: 'rgba(255,255,255,0.7)',
  },
  gridLineH: {
    position: 'absolute',
    top: '33.3%',
    height: 0.8,
    width: '100%',
    backgroundColor: 'rgba(255,255,255,0.7)',
  },
  gridLineH2: {
    position: 'absolute',
    top: '66.6%',
    height: 0.8,
    width: '100%',
    backgroundColor: 'rgba(255,255,255,0.7)',
  },
  corner: {
    position: 'absolute',
    width: 44,
    height: 44,
    borderColor: '#fff',
    backgroundColor: 'transparent',
    zIndex: 20,
  },
  cornerTL: { top: -4, left: -4, borderTopWidth: 4, borderLeftWidth: 4 },
  cornerTR: { top: -4, right: -4, borderTopWidth: 4, borderRightWidth: 4 },
  cornerBL: { bottom: -4, left: -4, borderBottomWidth: 4, borderLeftWidth: 4 },
  cornerBR: { bottom: -4, right: -4, borderBottomWidth: 4, borderRightWidth: 4 },

  rotationRuler: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    marginBottom: 24,
    height: 60,
  },
  rulerIcon: { color: '#fff', fontSize: 22 },
  rulerCenter: { flex: 1, alignItems: 'center' },
  rulerValue: { color: '#fff', fontSize: 13, fontWeight: '700', marginBottom: 10 },
  rulerMarks: { flexDirection: 'row', alignItems: 'flex-end', height: 20 },
  rulerMark: { width: 1, height: 8, backgroundColor: '#444', marginHorizontal: 3 },
  rulerMarkActive: { height: 16, backgroundColor: '#888' },

  transformBottomBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    height: '100%',
  },
  bottomBarIconBtn: { padding: 10 },
  bottomBarIcon: { color: '#fff', fontSize: 20, fontWeight: '700' },
  bottomBarTitle: { color: '#fff', fontSize: 13, fontWeight: '700', letterSpacing: 1.2 },

  // Text Overlay Styles
  textOverlayContainer: {
    position: 'absolute',
    padding: 8,
    zIndex: 30,
  },
  textOverlay: {
    fontWeight: '700',
  },
  selectedTextContainer: {
    borderWidth: 1,
    borderColor: '#38bdf8',
    borderStyle: 'dashed',
    borderRadius: 4,
  },
  textActionRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginBottom: 16,
  },
  addTextBtn: {
    backgroundColor: '#38bdf8',
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 20,
  },
  addTextBtnText: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 14,
  },
  textEditControls: {
    marginTop: 10,
  },
  controlSubTitle: {
    color: '#999',
    fontSize: 12,
    fontWeight: '600',
    marginBottom: 10,
    textTransform: 'uppercase',
  },
  colorOption: {
    width: 36,
    height: 36,
    borderRadius: 18,
    marginRight: 12,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  colorOptionActive: {
    borderColor: '#38bdf8',
    transform: [{ scale: 1.1 }],
  },
  textEmptyState: {
    alignItems: 'center',
    padding: 20,
  },
  emptyStateText: {
    color: '#555',
    fontSize: 14,
    textAlign: 'center',
  },
  fontSizeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 20,
    justifyContent: 'center',
  },
  fontSizeLabel: {
    color: '#999',
    marginRight: 15,
    fontSize: 14,
  },
  sizeBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#222',
    alignItems: 'center',
    justifyContent: 'center',
  },
  sizeBtnText: {
    color: '#fff',
    fontSize: 20,
    fontWeight: '700',
  },
  sizeValue: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
    marginHorizontal: 20,
    minWidth: 30,
    textAlign: 'center',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.85)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  modalContent: {
    width: '100%',
    backgroundColor: '#1a1a1a',
    borderRadius: 15,
    padding: 20,
    alignItems: 'center',
  },
  modalInput: {
    width: '100%',
    color: '#fff',
    fontSize: 24,
    fontWeight: '700',
    textAlign: 'center',
    paddingVertical: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#333',
    marginBottom: 20,
  },
  modalColorPicker: {
    width: '100%',
    marginBottom: 20,
  },
  modalActions: {
    flexDirection: 'row',
    marginTop: 20,
    justifyContent: 'flex-end',
    width: '100%',
  },
  modalBtn: {
    paddingHorizontal: 20,
    paddingVertical: 10,
    marginLeft: 10,
  },
  modalBtnPrimary: {
    backgroundColor: '#38bdf8',
    borderRadius: 8,
  },
  modalBtnText: {
    color: '#999',
    fontSize: 16,
    fontWeight: '600',
  },
  modalBtnTextPrimary: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
  },
  floatingMusicBadge: {
    position: 'absolute',
    top: 20,
    right: 20,
    backgroundColor: 'rgba(0, 0, 0, 0.75)',
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 6,
    flexDirection: 'row',
    alignItems: 'center',
    zIndex: 30,
  },
  floatingMusicBadgeText: {
    color: '#FFF',
    fontSize: 12,
    fontWeight: '600',
  },
  musicModalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0)',
    justifyContent: 'flex-end',
  },
  musicModalContent: {
    backgroundColor: '#12141C',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    height: '50%',
    paddingTop: 12,
  },
  musicModalHandle: {
    width: 36,
    height: 4.5,
    borderRadius: 2.5,
    backgroundColor: '#2C303E',
    alignSelf: 'center',
    marginBottom: 16,
  },
  musicModalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    marginBottom: 16,
  },
  musicModalTitle: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: '700',
  },
  musicModalCloseBtn: {
    padding: 6,
  },
  musicModalCloseText: {
    color: '#A2A2A5',
    fontSize: 16,
    fontWeight: '600',
  },
  musicSearchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1C1F2E',
    borderRadius: 12,
    marginHorizontal: 16,
    paddingHorizontal: 12,
    height: 40,
    marginBottom: 16,
  },
  musicSearchIcon: {
    fontSize: 14,
    marginRight: 8,
    color: '#7D8395',
  },
  musicSearchInput: {
    flex: 1,
    color: '#FFFFFF',
    fontSize: 15,
    padding: 0,
  },
  musicSearchClearBtn: {
    padding: 4,
  },
  musicSearchClearText: {
    color: '#8E93A2',
    fontSize: 12,
    fontWeight: '700',
  },
  musicTabsContainer: {
    paddingHorizontal: 16,
    marginBottom: 16,
  },
  musicTabPill: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#1C1F2E',
    marginRight: 8,
  },
  musicTabPillActive: {
    backgroundColor: '#FFFFFF',
  },
  musicTabLabel: {
    color: '#8E93A2',
    fontSize: 13,
    fontWeight: '600',
  },
  musicTabLabelActive: {
    color: '#000000',
  },
  musicRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 18,
  },
  musicRowSelected: {
    backgroundColor: '#1E2436',
  },
  musicRowIndex: {
    color: '#525866',
    fontSize: 13,
    fontWeight: '600',
    width: 24,
  },
  musicRowCover: {
    width: 44,
    height: 44,
    borderRadius: 8,
    marginRight: 12,
  },
  musicRowInfo: {
    flex: 1,
    justifyContent: 'center',
  },
  musicRowTitle: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '600',
    marginBottom: 2,
  },
  musicRowArtist: {
    color: '#8E93A2',
    fontSize: 12,
  },
  musicSaveBtn: {
    padding: 8,
  },
  musicSaveIcon: {
    fontSize: 16,
  },
  musicPlayingIndicator: {
    marginRight: 10,
    backgroundColor: 'rgba(56, 189, 248, 0.1)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  musicListEmpty: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 40,
  },
  musicListEmptyText: {
    color: '#8E93A2',
    fontSize: 14,
  },
  musicModalFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#12141C',
    borderTopWidth: 1,
    borderTopColor: '#1D202F',
    paddingBottom: 24,
  },
  musicFooterLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
    marginRight: 16,
  },
  musicFooterCover: {
    width: 36,
    height: 36,
    borderRadius: 6,
    marginRight: 10,
  },
  musicFooterTitle: {
    color: '#FFFFFF',
    fontSize: 13,
    fontWeight: '600',
  },
  musicFooterArtist: {
    color: '#8E93A2',
    fontSize: 11,
    marginTop: 1,
  },
  musicFooterRemoveBtn: {
    backgroundColor: 'rgba(239, 68, 68, 0.1)',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 14,
  },
  musicFooterRemoveText: {
    color: '#EF4444',
    fontSize: 12,
    fontWeight: '600',
  },
  backButton: {
    padding: 10,
  },
  backButtonText: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: '600',
  },
  soundButton: {
    padding: 10,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    borderRadius: 20,
    marginRight: 10,
  },
  soundIconText: {
    fontSize: 18,
  },
  cardContainer: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  cardPreviewBox: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 5,
  },
  cropIconBtn: {
    position: 'absolute',
    bottom: 12,
    left: 12,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    width: 36,
    height: 36,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 30,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.3)',
  },
  globalTrashZone: {
    position: 'absolute',
    bottom: Platform.OS === 'ios' ? 48 : 28,
    left: 0,
    right: 0,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 9999,
  },
  trashZoneContainer: {
    backgroundColor: 'rgba(0, 0, 0, 0.75)',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 24,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.25)',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 6,
    elevation: 8,
  },
  trashZoneActive: {
    backgroundColor: '#ef4444',
    borderColor: '#fca5a5',
  },
  trashZoneText: {
    color: '#ffffff',
    fontSize: 12,
    fontWeight: '700',
    marginLeft: 8,
  },
  cropIconText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
  },
  bottomToolBarContainer: {
    backgroundColor: '#0A0A0C',
    borderTopWidth: 1,
    borderTopColor: '#1A1A1E',
    paddingBottom: Platform.OS === 'ios' ? 24 : 12,
  },
  toolButtonsRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: 10,
    paddingHorizontal: 4,
    borderBottomWidth: 1,
    borderBottomColor: '#1A1A1E',
  },
  toolButton: {
    alignItems: 'center',
    justifyContent: 'center',
    width: 52,
  },
  toolButtonActive: {
    transform: [{ scale: 1.05 }],
  },
  toolIconContainer: {
    width: 42,
    height: 42,
    borderRadius: 8,
    backgroundColor: 'rgba(255, 255, 255, 0.08)',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 4,
  },
  toolIconText: {
    fontSize: 15,
    color: '#FFFFFF',
    fontWeight: '600',
    textAlign: 'center',
    textAlignVertical: 'center',
    includeFontPadding: false,
  },
  toolLabel: {
    fontSize: 9,
    color: '#FFFFFF',
    fontWeight: '500',
    textAlign: 'center',
  },
  bottomNavButtonsRow: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  addMediaButton: {
    position: 'relative',
  },
  addMediaThumb: {
    width: 44,
    height: 44,
    borderRadius: 22,
    borderWidth: 1.5,
    borderColor: '#38bdf8',
  },
  addMediaPlusBadge: {
    position: 'absolute',
    bottom: -3,
    right: -3,
    backgroundColor: '#38bdf8',
    width: 18,
    height: 18,
    borderRadius: 9,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1.5,
    borderColor: '#000',
  },
  addMediaPlusText: {
    color: '#FFF',
    fontSize: 11,
    fontWeight: 'bold',
  },
  nextBlueBtn: {
    backgroundColor: '#007AFF',
    paddingVertical: 10,
    paddingHorizontal: 24,
    borderRadius: 22,
    shadowColor: '#007AFF',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
    elevation: 3,
  },
  nextBlueText: {
    color: '#FFF',
    fontSize: 14,
    fontWeight: '700',
  },
  addTextPill: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(56, 189, 248, 0.1)',
    borderWidth: 1,
    borderColor: '#38bdf8',
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 20,
  },
  addTextPillText: {
    color: '#38bdf8',
    fontSize: 13,
    fontWeight: '700',
  },

  // ── Stickers ────────────────────────────────────────────────────────────────
  stickerBtn: {
    width: 52,
    height: 52,
    borderRadius: 12,
    backgroundColor: 'rgba(255,255,255,0.07)',
    alignItems: 'center',
    justifyContent: 'center',
    margin: 4,
  },
  stickerEmoji: {
    fontSize: 28,
  },
  addedStickerChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 20,
    paddingHorizontal: 8,
    paddingVertical: 4,
    marginRight: 6,
    marginBottom: 4,
  },

  // ── Effects ─────────────────────────────────────────────────────────────────
  effectThumb: {
    alignItems: 'center',
    marginHorizontal: 6,
    opacity: 0.7,
  },
  effectThumbActive: {
    opacity: 1,
  },
  effectIconBox: {
    width: 62,
    height: 62,
    borderRadius: 14,
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderWidth: 2,
    borderColor: 'transparent',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 4,
  },

  // ── Captions ─────────────────────────────────────────────────────────────────
  captionStylePill: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#334155',
    marginRight: 8,
    backgroundColor: 'rgba(255,255,255,0.05)',
  },
  captionStylePillActive: {
    borderColor: '#3b82f6',
    backgroundColor: 'rgba(59,130,246,0.2)',
  },
  captionInputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.07)',
    borderRadius: 12,
    paddingHorizontal: 10,
    paddingVertical: 4,
    gap: 8,
  },
  captionInput: {
    flex: 1,
    color: '#fff',
    fontSize: 14,
    paddingVertical: 6,
  },
  captionAddBtn: {
    backgroundColor: '#3b82f6',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 10,
  },
  captionListItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 6,
    gap: 8,
  },
  captionPreviewChip: {
    flex: 1,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
  },
  captionPreviewText: {
    fontSize: 13,
  },
  captionRemoveBtn: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: 'rgba(255,100,100,0.15)',
    alignItems: 'center',
    justifyContent: 'center',
  },

  // ── Add Clip ─────────────────────────────────────────────────────────────────
  addClipBigBtn: {
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(59,130,246,0.12)',
    borderWidth: 2,
    borderColor: '#3b82f6',
    borderStyle: 'dashed',
    borderRadius: 20,
    paddingVertical: 20,
    paddingHorizontal: 40,
  },
  addClipBigText: {
    color: '#3b82f6',
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 2,
  },
  addClipSubText: {
    color: '#64748b',
    fontSize: 12,
  },
});

function TrayButton({ label, onPress, disabled, active }: { label: string; onPress: () => void; disabled?: boolean; active?: boolean }) {
  return (
    <Pressable
      style={[styles.trayButton, active && styles.trayButtonActive, disabled && styles.trayButtonDisabled]}
      onPress={onPress}
      disabled={disabled}
    >
      <Text style={styles.trayButtonText}>{label}</Text>
    </Pressable>
  );
}

function AdjustItem({
  label,
  value,
  onAdjust,
  min = 0,
  max = 2,
  isToggle,
  isAction,
  icon,
}: {
  label: string;
  value: number;
  onAdjust: (v: number) => void;
  min?: number;
  max?: number;
  isToggle?: boolean;
  isAction?: boolean;
  icon?: string;
}) {
  const handleIncrease = () => {
    if (isToggle || isAction) {
      onAdjust(value);
    } else {
      onAdjust(Math.min(max, value + 0.1));
    }
  };

  const handleDecrease = () => {
    if (isToggle || isAction) {
      onAdjust(value);
    } else {
      onAdjust(Math.max(min, value - 0.1));
    }
  };

  const isChanged = () => {
    if (isToggle) return value === 1;
    if (isAction) return false;
    if (label === 'Contrast' || label === 'Saturation') return Math.abs(value - 1) > 0.01;
    return Math.abs(value) > 0.01;
  };

  return (
    <View style={styles.adjustItem}>
      <Text style={styles.adjustLabel}>{label}</Text>
      <View style={styles.row}>
        {!isToggle && !isAction && (
          <Pressable style={styles.adjustSmallButton} onPress={handleDecrease}>
            <Text style={styles.adjustSmallButtonText}>-</Text>
          </Pressable>
        )}
        <Pressable
          style={[styles.adjustCircle, isChanged() && styles.adjustCircleActive]}
          onPress={handleIncrease}
        >
          {icon ? (
            <Text style={[styles.adjustValue, { fontSize: 18 }]}>{icon}</Text>
          ) : (
            <Text style={styles.adjustValue}>
              {isToggle ? (value ? 'ON' : 'OFF') : value.toFixed(1)}
            </Text>
          )}
        </Pressable>
        {!isToggle && !isAction && (
          <Pressable style={styles.adjustSmallButton} onPress={handleIncrease}>
            <Text style={styles.adjustSmallButtonText}>+</Text>
          </Pressable>
        )}
      </View>
    </View>
  );
}

function AspectRatioItem({ label, active, onPress, width, height, isReset }: any) {
  return (
    <Pressable style={styles.aspectItem} onPress={onPress}>
      <View style={styles.aspectIconContainer}>
        {isReset ? (
          <Text style={styles.resetIcon}>↺</Text>
        ) : label === 'Custom' ? (
          <View style={[styles.aspectDashed, active && styles.aspectActiveBorder]} />
        ) : label === 'Square' ? (
          <View style={[styles.aspectBox, { aspectRatio: 1 }, active && styles.aspectActiveBorder]} />
        ) : label === '16:9' ? (
          <View style={[styles.aspectBox, { aspectRatio: 16 / 9, justifyContent: 'center', alignItems: 'center' }, active && styles.aspectActiveBorder]}>
            <Text style={{ color: active ? '#fff' : '#999', fontSize: 10 }}>↔</Text>
          </View>
        ) : (
          <View style={[styles.aspectBox, { aspectRatio: (width || 1) / (height || 1) }, active && styles.aspectActiveBorder]} />
        )}
      </View>
      <Text style={[styles.aspectLabel, active && styles.aspectLabelActive]}>{label}</Text>
    </Pressable>
  );
}
