import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Alert,
  Animated,
  FlatList,
  Image,
  Modal,
  PermissionsAndroid,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import Ionicons from 'react-native-vector-icons/Ionicons';
import ImagePicker from 'react-native-image-crop-picker';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { CameraView, CameraViewRef } from '../native/CameraView';
import { Album, exportAsset, listAlbums, listMedia, requestMediaAccess } from '../native/MediaLibrary';
import { VideoPreview } from '../native/VideoPreview';
import type { MediaItem } from '../types';

const TABS: Array<'GALLERY' | 'PHOTO' | 'VIDEO'> = ['GALLERY', 'PHOTO', 'VIDEO'];
const POST_TYPES: Array<'POST' | 'STORY' | 'REEL'> = ['POST', 'STORY', 'REEL'];


const CameraIcon = () => (
  <View style={{ width: 30, height: 22, borderWidth: 2, borderColor: '#fff', borderRadius: 4, alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
    <View style={{ width: 10, height: 10, borderRadius: 5, borderWidth: 2, borderColor: '#fff' }} />
    <View style={{ width: 6, height: 3, backgroundColor: '#fff', position: 'absolute', top: -4, left: 4, borderRadius: 1 }} />
  </View>
);

function formatDuration(ms?: number) {
  if (!ms || ms <= 0) return '';
  const total = Math.floor(ms / 1000);
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export function PickScreen({
  items,
  onPicked,
  onNext,
  headerTitle = 'New post',
  customCancelIcon,
  onCancelPress,
  cameraModes = ['POST', 'STORY', 'REEL'],
  onCameraModeChange,
  defaultCameraMode,
}: {
  items: MediaItem[];
  onPicked: (items: MediaItem[]) => void;
  onNext: (picked: MediaItem[]) => void;
  headerTitle?: string;
  customCancelIcon?: React.ReactNode;
  onCancelPress?: () => void;
  cameraModes?: string[];
  onCameraModeChange?: (mode: string) => void;
  defaultCameraMode?: string;
}) {
  const insets = useSafeAreaInsets();
  const [tab, setTab] = useState<'GALLERY' | 'PHOTO' | 'VIDEO'>('GALLERY');
  const [activeAlbum, setActiveAlbum] = useState<Album>({ id: 'all', title: 'Recents' });
  const [showAlbumPicker, setShowAlbumPicker] = useState(false);
  const [postType, setPostType] = useState<'POST' | 'STORY' | 'REEL'>('POST');
  const [multiSelect, setMultiSelect] = useState(false);
  const [selectedItems, setSelectedItems] = useState<MediaItem[]>([]);
  const [selectedMedia, setSelectedMedia] = useState<MediaItem | null>(null);
  const [library, setLibrary] = useState<MediaItem[]>([]);
  const [albums, setAlbums] = useState<Album[]>([]);
  const [loading, setLoading] = useState(false);
  const [previewUri, setPreviewUri] = useState<string | null>(null);
  const [cropMode, setCropMode] = useState<'1:1' | 'original'>('1:1');
  const [videoPaused, setVideoPaused] = useState(false);
  const scaleAnim = useRef(new Animated.Value(1)).current;

  const [showCustomCamera, setShowCustomCamera] = useState(false);
  const [facing, setFacing] = useState<'front' | 'back'>('front');
  const [flashMode, setFlashMode] = useState<'on' | 'off'>('off');
  const [isRecording, setIsRecording] = useState(false);
  const isRecordingRef = useRef(false);
  const cameraRef = useRef<CameraViewRef>(null);
  const [activeCameraMode, setActiveCameraMode] = useState<string>(() => {
    if (defaultCameraMode) {
      const matched = cameraModes.find(m => m.toUpperCase() === defaultCameraMode.toUpperCase());
      if (matched) return matched;
    }
    return cameraModes.includes('STORY') ? 'STORY' : (cameraModes[0] || 'STORY');
  });

  useEffect(() => {
    onCameraModeChange?.(activeCameraMode);
  }, [activeCameraMode, onCameraModeChange]);

  const handleCameraMediaCaptured = (uri: string, type: 'image' | 'video', width: number, height: number, durationMs?: number) => {
    setShowCustomCamera(false);
    const item: MediaItem = {
      id: 'camera_' + Date.now(),
      uri: uri,
      type: type,
      thumbnailUri: uri,
      width: width,
      height: height,
      durationMs: durationMs,
    };
    setLibrary((prev) => [item, ...prev]);
    setSelectedMedia(item);
    setSelectedItems([item]);
    onPicked([item]);
    onNext([item]);
  };

  const handlePress = async () => {
    if (isRecordingRef.current) {
      return;
    }
    try {
      const photo = await cameraRef.current?.capturePhoto();
      if (photo) {
        handleCameraMediaCaptured(photo.uri, 'image', photo.width, photo.height);
      }
    } catch (err: any) {
      console.error('PickScreen: capturePhoto error:', err);
      Alert.alert('Capture Error', err?.message ?? 'Failed to capture photo');
    }
  };

  const handleLongPress = async () => {
    try {
      isRecordingRef.current = true;
      setIsRecording(true);
      await cameraRef.current?.startRecording();
    } catch (err: any) {
      isRecordingRef.current = false;
      setIsRecording(false);
      Alert.alert('Recording Error', err?.message ?? 'Failed to start recording');
    }
  };

  const handlePressOut = async () => {
    if (!isRecordingRef.current) return;
    try {
      const video = await cameraRef.current?.stopRecording();
      isRecordingRef.current = false;
      setIsRecording(false);
      if (video) {
        handleCameraMediaCaptured(video.uri, 'video', video.width, video.height, video.durationMs);
      }
    } catch (err: any) {
      isRecordingRef.current = false;
      setIsRecording(false);
      Alert.alert('Recording Error', err?.message ?? 'Failed to stop recording');
    }
  };

  const loadMedia = async (albumId?: string) => {
    try {
      setLoading(true);
      const assets = await listMedia({
        limit: 200,
        offset: 0,
        type: 'all',
        albumId: albumId === 'all' ? undefined : albumId,
      });
      setLibrary(assets);
      if (assets[0] && !multiSelect) {
        setSelectedMedia(assets[0]);
      }
    } catch (err: any) {
      Alert.alert('Library error', err?.message ?? 'Failed to load library.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    (async () => {
      try {
        const ok = await requestMediaAccess();
        if (!ok) {
          Alert.alert('Permission needed', 'Allow photo access to continue.');
          return;
        }
        const fetchedAlbums = await listAlbums();
        setAlbums([{ id: 'all', title: 'Recents' }, ...fetchedAlbums]);
        loadMedia('all');
      } catch (err: any) {
        console.error('Initial load failed', err);
      }
    })();
  }, []);

  const filtered = useMemo(() => {
    let list = library;
    if (tab === 'PHOTO') list = library.filter((i) => i.type === 'image');
    else if (tab === 'VIDEO') list = library.filter((i) => i.type === 'video');

    const cameraItem: MediaItem = {
      id: 'camera_trigger',
      uri: 'camera_trigger',
      type: 'image',
    };
    return [cameraItem, ...list];
  }, [library, tab]);

  useEffect(() => {
    let cancelled = false;
    setVideoPaused(false);
    (async () => {
      if (!selectedMedia) {
        setPreviewUri(null);
        return;
      }
      if (!selectedMedia.uri.startsWith('ph://') && !selectedMedia.uri.startsWith('content://')) {
        setPreviewUri(selectedMedia.uri);
        return;
      }
      try {
        const fileUri = await exportAsset(selectedMedia.id);
        if (!cancelled) setPreviewUri(fileUri);
      } catch {
        if (!cancelled) setPreviewUri(null);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [selectedMedia]);

  const playableUri = useMemo(() => {
    if (!selectedMedia) return null;
    if (previewUri && !previewUri.startsWith('ph://') && !previewUri.startsWith('content://')) return previewUri;
    if (selectedMedia.uri && !selectedMedia.uri.startsWith('ph://') && !selectedMedia.uri.startsWith('content://')) return selectedMedia.uri;
    return null;
  }, [previewUri, selectedMedia]);

  const toggleMultiSelect = () => {
    setMultiSelect((v) => !v);
    setSelectedItems([]);
  };

  const handleSelectItem = (item: MediaItem) => {
    setSelectedMedia(item);
    if (multiSelect) {
      setSelectedItems((prev) => {
        const exists = prev.find((i) => i.id === item.id);
        if (exists) return prev.filter((i) => i.id !== item.id);
        if (prev.length >= 10) return prev;
        return [...prev, item];
      });
    }

    Animated.sequence([
      Animated.timing(scaleAnim, { toValue: 0.97, duration: 80, useNativeDriver: true }),
      Animated.timing(scaleAnim, { toValue: 1, duration: 80, useNativeDriver: true }),
    ]).start();
  };

  const handleLongPressItem = (item: MediaItem) => {
    if (!multiSelect) {
      setMultiSelect(true);
      setSelectedItems([item]);
      setSelectedMedia(item);

      Animated.sequence([
        Animated.timing(scaleAnim, { toValue: 0.97, duration: 80, useNativeDriver: true }),
        Animated.timing(scaleAnim, { toValue: 1, duration: 80, useNativeDriver: true }),
      ]).start();
    }
  };

  const openImageCropPickerCamera = async (type: 'photo' | 'video') => {
    try {
      const result = await ImagePicker.openCamera({
        mediaType: type,
      });
      if (result) {
        const item: MediaItem = {
          id: 'camera_' + Date.now(),
          uri: result.path,
          type: type === 'photo' ? 'image' : 'video',
          thumbnailUri: result.path,
          width: result.width,
          height: result.height,
          durationMs: type === 'video' ? ((result as any).duration || 10000) : undefined,
        };
        setLibrary((prev) => [item, ...prev]);
        setSelectedMedia(item);
        setSelectedItems([item]);
        onPicked([item]);
        onNext([item]);
      }
    } catch (err: any) {
      if (err?.message !== 'User cancelled image selection' && err?.message !== 'User cancelled image selection.') {
        Alert.alert('Camera error', err?.message ?? 'Failed to open camera.');
      }
    }
  };

  const handleOpenCamera = async () => {
    if (Platform.OS === 'android') {
      try {
        const cameraGranted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.CAMERA,
          {
            title: 'Camera Permission',
            message: 'App needs access to your camera to take photos and record videos.',
            buttonNeutral: 'Ask Me Later',
            buttonNegative: 'Cancel',
            buttonPositive: 'OK',
          }
        );

        const audioGranted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
          {
            title: 'Microphone Permission',
            message: 'App needs access to your microphone to record audio for videos.',
            buttonNeutral: 'Ask Me Later',
            buttonNegative: 'Cancel',
            buttonPositive: 'OK',
          }
        );

        if (
          cameraGranted !== PermissionsAndroid.RESULTS.GRANTED ||
          audioGranted !== PermissionsAndroid.RESULTS.GRANTED
        ) {
          Alert.alert('Permissions Required', 'Camera and Microphone permissions are required to use the custom camera.');
          return;
        }
      } catch (err) {
        console.warn(err);
        return;
      }
    }
    setFacing('front');
    setShowCustomCamera(true);
  };

  const getSelectionIndex = (id: string) => {
    const idx = selectedItems.findIndex((i) => i.id === id);
    return idx === -1 ? null : idx + 1;
  };

  const handleNext = () => {
    const picked = multiSelect ? selectedItems : selectedMedia ? [selectedMedia] : [];
    if (picked.length === 0) {
      Alert.alert('Select media', 'Choose at least one item.');
      return;
    }
    onPicked(picked);
    onNext(picked);
  };

  const renderThumb = ({ item }: { item: MediaItem }) => {
    if (item.id === 'camera_trigger') {
      return (
        <Pressable style={styles.cameraGridContainer} onPress={handleOpenCamera}>
          <View style={styles.cameraGridBox}>
            <CameraIcon />
          </View>
        </Pressable>
      );
    }

    const thumbUri = item.thumbnailUri;
    const selIdx = getSelectionIndex(item.id);
    const isActive = multiSelect ? !!selIdx : selectedMedia?.id === item.id;

    return (
      <Pressable
        style={styles.thumbContainer}
        onPress={() => handleSelectItem(item)}
        onLongPress={() => handleLongPressItem(item)}
      >
        {thumbUri ? (
          <Image source={{ uri: thumbUri }} style={styles.thumb} />
        ) : (
          <View style={[styles.thumb, styles.thumbFallback]} />
        )}

        {isActive && !multiSelect && <View style={styles.activeOverlay} />}

        {multiSelect && (
          <View style={[styles.multiOverlay, isActive && styles.multiOverlayActive]}>
            {isActive ? (
              <View style={styles.selectionBadge}>
                <Text style={styles.selectionNumber}>{selIdx}</Text>
              </View>
            ) : (
              <View style={styles.emptyBadge} />
            )}
          </View>
        )}

        {item.type === 'video' && (
          <>
            <View style={styles.videoPlayBadge}>
              <Ionicons name="play" size={10} color="#fff" />
            </View>
            <View style={styles.videoBadge}>
              <Text style={styles.videoDuration}>{formatDuration(item.durationMs)}</Text>
            </View>
          </>
        )}
      </Pressable>
    );
  };

  return (
    <View style={styles.container}>

      <View style={styles.header}>
        <Pressable onPress={() => {
          if (onCancelPress) {
            onCancelPress();
          } else {
            onNext([]);
          }
        }}>
          {customCancelIcon ? (
            customCancelIcon
          ) : (
            <Ionicons name="close" size={22} color="#fff" />
          )}
        </Pressable>

        <Text style={styles.headerTitle}>{headerTitle}</Text>

        <Pressable style={styles.nextBtn} onPress={handleNext}>
          <Text style={styles.nextText}>Next</Text>
        </Pressable>
      </View>

      <Modal
        visible={showAlbumPicker}
        transparent
        animationType="slide"
        onRequestClose={() => setShowAlbumPicker(false)}
      >
        {/* Backdrop */}
        <Pressable style={styles.albumSheetBackdrop} onPress={() => setShowAlbumPicker(false)} />

        {/* Sheet */}
        <View style={styles.albumSheet}>
          {/* Handle */}
          <View style={styles.albumSheetHandle} />

          {/* Title */}
          <Text style={styles.albumSheetTitle}>Select Album</Text>

          <ScrollView bounces={false}>
            {albums.map((album) => (
              <Pressable
                key={album.id}
                style={styles.albumSheetOption}
                onPress={() => {
                  setActiveAlbum(album);
                  setShowAlbumPicker(false);
                  loadMedia(album.id);
                }}
              >
                <Text style={[
                  styles.albumSheetOptionText,
                  activeAlbum.id === album.id && styles.albumSheetOptionActive,
                ]}>
                  {album.title}
                </Text>
                {activeAlbum.id === album.id && (
                  <Ionicons name="checkmark" size={20} color="#3b82f6" />
                )}
              </Pressable>
            ))}
          </ScrollView>
        </View>
      </Modal>

      <Animated.View style={[styles.preview, { transform: [{ scale: scaleAnim }] }]}>
        {selectedMedia?.type === 'video' ? (
          <Pressable style={styles.previewImage} onPress={() => setVideoPaused((v) => !v)}>
            {playableUri ? (
              <VideoPreview
                uri={playableUri}
                paused={videoPaused}
                muted={false}
                style={styles.previewImage}
                resizeMode={cropMode === '1:1' ? 'cover' : 'contain'}
              />
            ) : (
              <Image
                source={{ uri: selectedMedia.thumbnailUri || selectedMedia.uri }}
                style={styles.previewImage}
                resizeMode="cover"
              />
            )}
            <View style={styles.previewOverlay}>
              <View style={styles.playPauseCircle}>
                <Ionicons name={videoPaused ? 'play' : 'pause'} size={24} color="#fff" />
              </View>
            </View>
          </Pressable>
        ) : (
          <Image
            source={{ uri: previewUri ?? selectedMedia?.uri }}
            style={[styles.previewImage, cropMode === '1:1' ? styles.squareCrop : styles.originalCrop]}
            resizeMode={cropMode === '1:1' ? 'cover' : 'contain'}
          />
        )}

        <View style={styles.previewControls}>
          <Pressable
            style={styles.cropToggle}
            onPress={() => setCropMode((v) => (v === '1:1' ? 'original' : '1:1'))}
          >
            <Ionicons
              name={cropMode === '1:1' ? 'square-outline' : 'expand-outline'}
              size={20}
              color="#fff"
            />
          </Pressable>
        </View>
      </Animated.View>

      <View style={styles.albumRow}>
        <Pressable
          style={styles.albumSelector}
          onPress={() => setShowAlbumPicker((v) => !v)}
        >
          <Text style={styles.albumTitle}>{activeAlbum.title}</Text>
          <Ionicons name="chevron-down" size={16} color="#fff" style={{ marginLeft: 6 }} />
        </Pressable>

        <Pressable style={[styles.multiSelectBtn, multiSelect && styles.multiSelectBtnActive]} onPress={toggleMultiSelect}>
          <Text style={[styles.multiSelectText, multiSelect && styles.multiSelectTextActive]}>{multiSelect ? 'Done' : 'Select'}</Text>
        </Pressable>
      </View>

      <FlatList
        data={filtered}
        keyExtractor={(item) => item.id}
        numColumns={4}
        style={styles.libraryList}
        renderItem={renderThumb}
        contentContainerStyle={styles.grid}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={styles.emptyText}>{loading ? 'Loading…' : 'No media found'}</Text>
          </View>
        }
      />

      <View style={styles.tabBar}>
        {TABS.map((t) => (
          <Pressable key={t} onPress={() => setTab(t)}>
            <Text style={[styles.tab, tab === t && styles.tabActive]}>{t}</Text>
          </Pressable>
        ))}
      </View>

      {/* <View style={styles.postTypeBar}>
        {POST_TYPES.map((t) => (
          <Pressable
            key={t}
            style={[styles.postTypeChip, postType === t && styles.postTypeChipActive]}
            onPress={() => setPostType(t)}
          >
            <Text style={[styles.postTypeText, postType === t && styles.postTypeTextActive]}>
              {t === 'POST' ? 'POST' : t === 'STORY' ? 'STORY' : 'REEL'}
            </Text>
          </Pressable>
        ))}
      </View> */}

      <Modal
        visible={showCustomCamera}
        animationType="slide"
        transparent={false}
        onRequestClose={() => setShowCustomCamera(false)}
      >
        <View style={styles.cameraContainer}>
          <CameraView
            ref={cameraRef}
            facing={facing}
            flashMode={facing === 'front' ? 'off' : flashMode}
            style={StyleSheet.absoluteFillObject}
          />

          {/* Rule of Thirds Grid Overlay */}
          <View style={styles.cameraGridOverlay} pointerEvents="none">
            <View style={styles.gridRow}>
              <View style={styles.gridCell} />
              <View style={[styles.gridCell, styles.gridCellMiddleCol]} />
              <View style={styles.gridCell} />
            </View>
            <View style={[styles.gridRow, styles.gridRowMiddleRow]}>
              <View style={styles.gridCell} />
              <View style={[styles.gridCell, styles.gridCellMiddleCol]} />
              <View style={styles.gridCell} />
            </View>
            <View style={styles.gridRow}>
              <View style={styles.gridCell} />
              <View style={[styles.gridCell, styles.gridCellMiddleCol]} />
              <View style={styles.gridCell} />
            </View>
          </View>

          {/* Top Controls */}
          <View style={[styles.cameraHeader, { top: Math.max(insets.top, 16) }]}>
            <Pressable style={styles.cameraCloseBtn} onPress={() => setShowCustomCamera(false)}>
              <Ionicons name="close" size={22} color="#fff" />
            </Pressable>

            <Pressable
              style={[styles.cameraFlashContainer, facing === 'front' && { opacity: 0.3 }]}
              onPress={() => setFlashMode((f) => (f === 'on' ? 'off' : 'on'))}
              disabled={facing === 'front'}
            >
              <Ionicons
                name={flashMode === 'on' && facing === 'back' ? 'flash' : 'flash-off'}
                size={22}
                color={flashMode === 'on' && facing === 'back' ? '#FFD700' : 'rgba(255,255,255,0.4)'}
              />
            </Pressable>
          </View>

          {/* Bottom Controls */}
          <View style={[styles.cameraFooter, { bottom: Math.max(insets.bottom + 60, 60) }]}>
            <View style={styles.cameraGalleryPreview}>
              {library.length > 1 && library[1].thumbnailUri ? (
                <Image source={{ uri: library[1].thumbnailUri }} style={styles.cameraGalleryThumb} />
              ) : (
                <View style={styles.cameraGalleryThumbPlaceholder} />
              )}
            </View>

            <Pressable
              style={[styles.captureRing, isRecording && styles.captureRingRecording]}
              onPress={handlePress}
              onLongPress={handleLongPress}
              onPressOut={handlePressOut}
              delayLongPress={200}
            >
              <View style={[styles.captureButton, isRecording && styles.captureButtonRecording]} />
            </Pressable>

            <Pressable
              style={styles.flipCameraBtn}
              onPress={() => setFacing((f) => (f === 'front' ? 'back' : 'front'))}
            >
              <Ionicons name="camera-reverse-outline" size={26} color="#fff" />
            </Pressable>
          </View>

          {/* Bottom Screen Mode Tabs */}
          <View style={[styles.cameraModeBar, { bottom: Math.max(insets.bottom + 12, 16) }]}>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.cameraModeScrollContainer}
            >
              {cameraModes.map((mode) => {
                const isActive = mode === activeCameraMode;
                return (
                  <Pressable key={mode} onPress={() => setActiveCameraMode(mode)}>
                    <Text style={isActive ? styles.cameraModeTextActive : styles.cameraModeTextInactive}>
                      {mode}
                    </Text>
                  </Pressable>
                );
              })}
            </ScrollView>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0b0f1a' },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 0,
    backgroundColor: '#0b0f1a',
    zIndex: 10,
    elevation: 10,
  },
  headerTitle: { color: '#fff', fontWeight: '700', fontSize: 18 },
  headerCancel: { fontSize: 20, color: '#fff' },
  nextBtn: {
    backgroundColor: '#2563eb',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
  },
  nextText: { color: '#fff', fontWeight: '700' },
  albumDropdown: {
    borderBottomWidth: 1,
    borderBottomColor: '#111827',
    backgroundColor: '#0b0f1a',
  },
  albumOption: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  albumOptionText: { fontSize: 14, color: '#e5e7eb' },
  albumOptionActive: { fontWeight: '700' },
  checkmark: { color: '#2563eb', fontWeight: '700' },
  // Bottom sheet styles
  albumSheetBackdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.55)',
  },
  albumSheet: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: '#161b2e',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingBottom: 32,
    maxHeight: '60%',
  },
  albumSheetHandle: {
    width: 40,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#3f4a6e',
    alignSelf: 'center',
    marginTop: 12,
    marginBottom: 6,
  },
  albumSheetTitle: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
    textAlign: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#1f2a45',
  },
  albumSheetOption: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#1a2240',
  },
  albumSheetOptionText: {
    fontSize: 15,
    color: '#cbd5e1',
  },
  albumSheetOptionActive: {
    color: '#fff',
    fontWeight: '700',
  },
  albumSheetCheckmark: {
    color: '#3b82f6',
    fontSize: 18,
    fontWeight: '700',
  },
  preview: { width: '100%', height: 420, backgroundColor: '#0f172a', overflow: 'hidden' },
  previewImage: { width: '100%', height: '100%', overflow: 'hidden' },
  squareCrop: { height: '100%' },
  originalCrop: { height: '100%' },
  previewControls: {
    position: 'absolute',
    left: 16,
    right: 16,
    bottom: 16,
    flexDirection: 'row',
    justifyContent: 'flex-start',
    alignItems: 'center',
  },
  cropToggle: {
    backgroundColor: 'rgba(0,0,0,0.65)',
    width: 34,
    height: 34,
    borderRadius: 17,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cropIcon: { color: '#fff', fontSize: 16 },
  albumRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  albumSelector: { flexDirection: 'row', alignItems: 'center' },
  albumTitle: { fontSize: 16, fontWeight: '700', color: '#fff' },
  albumArrow: {
    width: 10,
    height: 10,
    borderRightWidth: 2,
    borderBottomWidth: 2,
    borderColor: '#fff',
    marginLeft: 8,
    marginTop: -4,
    transform: [{ rotate: '45deg' }],
  },
  multiSelectBtn: {
    backgroundColor: '#111827',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 18,
  },
  cameraGridContainer: {
    width: '25%',
    aspectRatio: 1,
    padding: 1,
  },
  cameraGridBox: {
    flex: 1,
    backgroundColor: '#262626',
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  multiSelectBtnActive: { backgroundColor: '#2563eb' },
  multiSelectText: { color: '#e5e7eb', fontSize: 12, fontWeight: '700' },
  multiSelectTextActive: { color: '#fff' },
  postTypeBar: {
    flexDirection: 'row',
    justifyContent: 'space-evenly',
    paddingVertical: 12,
    backgroundColor: '#0b0f1a',
  },
  postTypeChip: {
    paddingHorizontal: 28,
    paddingVertical: 10,
    borderRadius: 20,
    backgroundColor: '#111827',
  },
  postTypeChipActive: { backgroundColor: '#1d4ed8' },
  postTypeText: { color: '#9ca3af', fontWeight: '700', letterSpacing: 0.4 },
  postTypeTextActive: { color: '#fff' },
  grid: { paddingBottom: 80 },
  libraryList: { flex: 1 },
  thumbContainer: { width: '25%', aspectRatio: 1, padding: 1 },
  thumb: { width: '100%', height: '100%', borderRadius: 8 },
  thumbFallback: { backgroundColor: '#111' },
  activeOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(255,255,255,0.18)',
  },
  multiOverlay: {
    position: 'absolute',
    right: 6,
    top: 6,
  },
  multiOverlayActive: {},
  selectionBadge: {
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: '#2563eb',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1.5,
    borderColor: '#fff',
  },
  selectionNumber: { color: '#fff', fontSize: 11, fontWeight: '700' },
  emptyBadge: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 1.5,
    borderColor: '#fff',
    backgroundColor: 'rgba(0,0,0,0.25)',
  },
  videoBadge: {
    position: 'absolute',
    right: 6,
    bottom: 6,
    backgroundColor: 'rgba(0,0,0,0.6)',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
  },
  videoDuration: { color: '#fff', fontSize: 10, fontWeight: '600' },
  videoPlayBadge: {
    position: 'absolute',
    left: 6,
    top: 6,
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: 'rgba(0,0,0,0.6)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  videoPlayIcon: { color: '#fff', fontSize: 10, fontWeight: '700' },
  previewOverlay: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 14,
    alignItems: 'center',
  },
  playPauseCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(0,0,0,0.55)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  playPauseText: { color: '#fff', fontSize: 18, fontWeight: '700' },
  empty: { padding: 24, alignItems: 'center' },
  emptyText: { color: '#6b7280' },
  tabBar: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: 10,
    borderTopWidth: 1,
    borderTopColor: '#111827',
  },
  tab: { color: '#6b7280', fontWeight: '700' },
  tabActive: { color: '#fff' },
  cameraContainer: {
    flex: 1,
    backgroundColor: '#000',
  },
  cameraGridOverlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'space-between',
    paddingVertical: 120,
  },
  gridRow: {
    flex: 1,
    flexDirection: 'row',
  },
  gridRowMiddleRow: {
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.15)',
  },
  gridCell: {
    flex: 1,
  },
  gridCellMiddleCol: {
    borderLeftWidth: 1,
    borderRightWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.15)',
  },
  cameraHeader: {
    position: 'absolute',
    top: 40,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    zIndex: 10,
  },
  cameraCloseBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(0,0,0,0.3)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  cameraCloseText: {
    color: '#fff',
    fontSize: 20,
    fontWeight: '300',
  },
  cameraFlashContainer: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(0,0,0,0.3)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  cameraHeaderText: {
    color: '#fff',
    fontSize: 20,
  },
  cameraHeaderActiveText: {
    color: '#FFD700',
  },
  cameraFooter: {
    position: 'absolute',
    bottom: 80,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 40,
    zIndex: 10,
  },
  cameraGalleryPreview: {
    width: 44,
    height: 44,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#fff',
    overflow: 'hidden',
    backgroundColor: '#333',
  },
  cameraGalleryThumb: {
    width: '100%',
    height: '100%',
  },
  cameraGalleryThumbPlaceholder: {
    width: '100%',
    height: '100%',
    backgroundColor: '#333',
  },
  captureRing: {
    width: 84,
    height: 84,
    borderRadius: 42,
    borderWidth: 4,
    borderColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'transparent',
  },
  captureRingRecording: {
    borderColor: 'rgba(255, 0, 0, 0.4)',
  },
  captureButton: {
    width: 66,
    height: 66,
    borderRadius: 33,
    backgroundColor: '#fff',
  },
  captureButtonRecording: {
    backgroundColor: '#ef4444',
    borderRadius: 8,
    width: 32,
    height: 32,
  },
  flipCameraBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(0,0,0,0.3)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  flipCameraText: {
    color: '#fff',
    fontSize: 22,
  },
  cameraModeBar: {
    position: 'absolute',
    bottom: 30,
    left: 0,
    right: 0,
    flexDirection: 'row',
    zIndex: 10,
  },
  cameraModeScrollContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    minWidth: '100%',
    paddingHorizontal: 20,
  },
  cameraModeTextActive: {
    color: '#fff',
    fontSize: 13,
    fontWeight: 'bold',
    marginHorizontal: 15,
    letterSpacing: 1.5,
  },
  cameraModeTextInactive: {
    color: 'rgba(255, 255, 255, 0.5)',
    fontSize: 13,
    fontWeight: '600',
    marginHorizontal: 15,
    letterSpacing: 1.5,
  },
});
