import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Alert,
  Animated,
  FlatList,
  Image,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { exportAsset } from '../native/MediaLibrary';
import { VideoPreview } from '../native/VideoPreview';
import type { MediaItem } from '../types';

export function GalleryScreen({
  items,
  onBack,
  onSelect,
  onNext,
}: {
  items: MediaItem[];
  onBack: () => void;
  onSelect: (item: MediaItem) => void;
  onNext: () => void;
}) {
  const [selectedMedia, setSelectedMedia] = useState<MediaItem | null>(items[0] || null);
  const [previewUri, setPreviewUri] = useState<string | null>(null);
  const [cropMode, setCropMode] = useState<'1:1' | 'original'>('1:1');
  const [videoPaused, setVideoPaused] = useState(false);
  const scaleAnim = useRef(new Animated.Value(1)).current;

  // Sync selected media if items list changes
  useEffect(() => {
    if (items.length > 0) {
      const found = selectedMedia ? items.find((i) => i.id === selectedMedia.id) : null;
      if (found) {
        setSelectedMedia(found);
      } else {
        setSelectedMedia(items[0]);
      }
    } else {
      setSelectedMedia(null);
    }
  }, [items]);

  // Resolve ph:// asset URIs to cache paths
  useEffect(() => {
    let cancelled = false;
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

  const handleSelectItem = (item: MediaItem) => {
    if (selectedMedia?.id === item.id) {
      // Tap again on active item to edit it directly
      onSelect(item);
    } else {
      setSelectedMedia(item);
      setVideoPaused(false);
      Animated.sequence([
        Animated.timing(scaleAnim, { toValue: 0.97, duration: 80, useNativeDriver: true }),
        Animated.timing(scaleAnim, { toValue: 1, duration: 80, useNativeDriver: true }),
      ]).start();
    }
  };

  const getSelectionIndex = (id: string) => {
    const idx = items.findIndex((i) => i.id === id);
    return idx === -1 ? null : idx + 1;
  };

  const renderThumb = ({ item }: { item: MediaItem }) => {
    const thumbUri = item.thumbnailUri ?? item.uri;
    const isActive = selectedMedia?.id === item.id;
    const itemIndex = getSelectionIndex(item.id);

    return (
      <Pressable style={styles.thumbContainer} onPress={() => handleSelectItem(item)}>
        {thumbUri && !thumbUri.startsWith('ph://') ? (
          <Image source={{ uri: thumbUri }} style={styles.thumb} />
        ) : (
          <View style={[styles.thumb, styles.thumbFallback]} />
        )}

        {isActive && <View style={styles.activeOverlay} />}

        {itemIndex !== null && (
          <View style={styles.multiOverlay}>
            <View style={[styles.selectionBadge, isActive && styles.selectionBadgeActive]}>
              <Text style={styles.selectionNumber}>{itemIndex}</Text>
            </View>
          </View>
        )}

        {item.type === 'video' && (
          <>
            <View style={styles.videoPlayBadge}>
              <Text style={styles.videoPlayIcon}>▶</Text>
            </View>
            <View style={styles.videoBadge}>
              <Text style={styles.videoDuration}>
                {item.durationMs ? `${(item.durationMs / 1000).toFixed(0)}s` : 'video'}
              </Text>
            </View>
          </>
        )}

        <View style={styles.editLabelContainer}>
          <Text style={styles.editLabelText}>EDIT</Text>
        </View>
      </Pressable>
    );
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Pressable onPress={onBack} style={styles.backButton}>
          <Text style={styles.headerCancel}>✕</Text>
        </Pressable>

        <Text style={styles.headerTitle}>All Selected</Text>

        <Pressable style={styles.nextBtn} onPress={onNext}>
          <Text style={styles.nextText}>Next</Text>
        </Pressable>
      </View>

      {/* Main Preview Area */}
      <Animated.View style={[styles.preview, { transform: [{ scale: scaleAnim }] }]}>
        {selectedMedia ? (
          selectedMedia.type === 'video' ? (
            <Pressable style={styles.previewImage} onPress={() => setVideoPaused((v) => !v)}>
              {playableUri ? (
                <VideoPreview uri={playableUri} paused={videoPaused} muted={false} style={styles.previewImage} />
              ) : (
                <Image
                  source={{ uri: selectedMedia.thumbnailUri || selectedMedia.uri }}
                  style={styles.previewImage}
                  resizeMode="cover"
                />
              )}
              <View style={styles.previewOverlay}>
                <View style={styles.playPauseCircle}>
                  <Text style={styles.playPauseText}>{videoPaused ? '▶' : '❚❚'}</Text>
                </View>
              </View>
            </Pressable>
          ) : (
            <Pressable style={styles.previewImage} onPress={() => onSelect(selectedMedia)}>
              <Image
                source={{ uri: previewUri ?? selectedMedia.uri }}
                style={[styles.previewImage, cropMode === '1:1' ? styles.squareCrop : styles.originalCrop]}
                resizeMode={cropMode === '1:1' ? 'cover' : 'contain'}
              />
            </Pressable>
          )
        ) : (
          <View style={styles.emptyPreview}>
            <Text style={styles.emptyText}>No Media Selected</Text>
          </View>
        )}

        {selectedMedia && (
          <>
            {/* Crop Toggle (for images) */}
            {selectedMedia.type === 'image' && (
              <View style={styles.previewControls}>
                <Pressable
                  style={styles.cropToggle}
                  onPress={() => setCropMode((v) => (v === '1:1' ? 'original' : '1:1'))}
                >
                  <Text style={styles.cropIcon}>{cropMode === '1:1' ? '⊡' : '⊞'}</Text>
                </Pressable>
              </View>
            )}

            {/* Floating Edit Badge */}
            <Pressable
              style={styles.editBadge}
              onPress={() => onSelect(selectedMedia)}
            >
              <Text style={styles.editBadgeText}>🎨 Edit Media</Text>
            </Pressable>
          </>
        )}
      </Animated.View>

      {/* Row details */}
      <View style={styles.albumRow}>
        <View style={styles.albumSelector}>
          <Text style={styles.albumTitle}>Selected Items</Text>
        </View>
        {selectedMedia && (
          <View style={styles.itemCountBadge}>
            <Text style={styles.itemCountText}>
              {items.indexOf(selectedMedia) + 1} of {items.length}
            </Text>
          </View>
        )}
      </View>

      {/* Grid of Selected Items */}
      <FlatList
        data={items}
        keyExtractor={(item) => `${item.id}-${item.uri}`}
        numColumns={4}
        style={styles.libraryList}
        renderItem={renderThumb}
        contentContainerStyle={styles.grid}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={styles.emptyText}>No items picked yet.</Text>
          </View>
        }
      />
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
  backButton: {
    paddingVertical: 4,
    paddingHorizontal: 8,
  },
  nextBtn: {
    backgroundColor: '#2563eb',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
  },
  nextText: { color: '#fff', fontWeight: '700' },
  preview: { width: '100%', height: 420, backgroundColor: '#0f172a' },
  previewImage: { width: '100%', height: '100%' },
  squareCrop: { height: '100%' },
  originalCrop: { height: '100%' },
  previewControls: {
    position: 'absolute',
    left: 16,
    bottom: 16,
    flexDirection: 'row',
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
  editBadge: {
    position: 'absolute',
    right: 16,
    bottom: 16,
    backgroundColor: '#2563eb',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.35,
    shadowRadius: 4,
    elevation: 6,
  },
  editBadgeText: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 13,
  },
  albumRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  albumSelector: { flexDirection: 'row', alignItems: 'center' },
  albumTitle: { fontSize: 16, fontWeight: '700', color: '#fff' },
  itemCountBadge: {
    backgroundColor: '#111827',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 12,
  },
  itemCountText: { color: '#e5e7eb', fontSize: 12, fontWeight: '700' },
  grid: { paddingBottom: 40 },
  libraryList: { flex: 1 },
  thumbContainer: { width: '25%', aspectRatio: 1, padding: 1 },
  thumb: { width: '100%', height: '100%', borderRadius: 8 },
  thumbFallback: { backgroundColor: '#111' },
  activeOverlay: {
    ...StyleSheet.absoluteFillObject,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#2563eb',
    backgroundColor: 'rgba(37,99,235,0.12)',
  },
  multiOverlay: {
    position: 'absolute',
    right: 6,
    top: 6,
  },
  selectionBadge: {
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: 'rgba(0,0,0,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1.5,
    borderColor: '#fff',
  },
  selectionBadgeActive: {
    backgroundColor: '#2563eb',
  },
  selectionNumber: { color: '#fff', fontSize: 10, fontWeight: '700' },
  videoBadge: {
    position: 'absolute',
    right: 6,
    bottom: 6,
    backgroundColor: 'rgba(0,0,0,0.6)',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
  },
  videoDuration: { color: '#fff', fontSize: 9, fontWeight: '600' },
  videoPlayBadge: {
    position: 'absolute',
    left: 6,
    top: 6,
    width: 18,
    height: 18,
    borderRadius: 9,
    backgroundColor: 'rgba(0,0,0,0.6)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  videoPlayIcon: { color: '#fff', fontSize: 9, fontWeight: '700' },
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
  editLabelContainer: {
    position: 'absolute',
    bottom: 6,
    left: 6,
    backgroundColor: 'rgba(0,0,0,0.5)',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  editLabelText: { color: '#fff', fontSize: 9, fontWeight: '700' },
  empty: { padding: 24, alignItems: 'center' },
  emptyText: { color: '#6b7280' },
  emptyPreview: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
