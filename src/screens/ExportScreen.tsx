import React, { useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Image,
  Pressable,
  Dimensions,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { VideoPreview } from '../native/VideoPreview';
import type { MediaItem } from '../types';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

// Custom Home Icon
const HomeIcon = () => (
    <View style={iconStyles.homeContainer}>
        <View style={iconStyles.homeRoof} />
        <View style={iconStyles.homeBase} />
    </View>
);

const iconStyles = StyleSheet.create({
    homeContainer: { width: 24, height: 24, alignItems: 'center', justifyContent: 'center' },
    homeRoof: {
        width: 0,
        height: 0,
        borderLeftWidth: 10,
        borderRightWidth: 10,
        borderBottomWidth: 10,
        borderStyle: 'solid',
        backgroundColor: 'transparent',
        borderLeftColor: 'transparent',
        borderRightColor: 'transparent',
        borderBottomColor: '#fff',
        marginBottom: -2
    },
    homeBase: { width: 16, height: 10, backgroundColor: '#fff', borderRadius: 1 },
});

interface ExportScreenProps {
  editedMedia: Record<string, MediaItem>;
  onHome: () => void;
  onReEdit: (item: MediaItem) => void;
}

export function ExportScreen({ editedMedia, onHome, onReEdit }: ExportScreenProps) {
  const mediaList = useMemo(() => Object.values(editedMedia), [editedMedia]);
  const [selectedId, setSelectedId] = useState<string>(mediaList[0]?.id || '');
  
  const selectedItem = useMemo(() => 
    mediaList.find(m => m.id === selectedId) || mediaList[0],
    [mediaList, selectedId]
  );

  const renderItem = ({ item }: { item: MediaItem }) => {
    const isSelected = item.id === selectedId;
    return (
      <Pressable 
        style={[styles.thumbContainer, isSelected && styles.activeThumb]} 
        onPress={() => setSelectedId(item.id)}
      >
        <Image 
          source={{ uri: item.thumbnailUri || item.uri }} 
          style={styles.thumb} 
          resizeMode="cover"
        />
        {item.type === 'video' && (
          <View style={styles.videoBadge}>
            <Text style={styles.videoBadgeText}>▶</Text>
          </View>
        )}
      </Pressable>
    );
  };

  return (
    <View style={styles.container}>
      <View style={styles.safeArea}>
        {/* Header */}
        <View style={styles.header}>
          <Pressable onPress={onHome} style={styles.headerBtn}>
            <HomeIcon />
          </Pressable>
          <Text style={styles.headerTitle}>Exported Media</Text>
          <View style={{ width: 44 }} />
        </View>

        {/* Main Preview */}
        <View style={styles.previewSection}>
          {selectedItem ? (
            <View style={styles.mainPreviewWrapper}>
              {selectedItem.type === 'video' ? (
                <VideoPreview 
                  uri={selectedItem.uri} 
                  paused={false} 
                  muted={false} 
                  style={styles.mainPreview} 
                />
              ) : (
                <Image 
                  source={{ uri: selectedItem.uri }} 
                  style={styles.mainPreview} 
                  resizeMode="contain"
                />
              )}
            </View>
          ) : (
            <View style={styles.emptyView}>
              <Text style={styles.emptyText}>No exported media found.</Text>
            </View>
          )}
        </View>

        {/* List of Edited items */}
        <View style={styles.listSection}>
          <Text style={styles.listTitle}>All Edited Items ({mediaList.length})</Text>
          <FlatList
            data={mediaList}
            renderItem={renderItem}
            keyExtractor={item => item.id}
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.listContent}
          />
        </View>

        {/* Bottom Actions */}
        <View style={styles.footer}>
          <Pressable 
            style={styles.reEditBtn} 
            onPress={() => selectedItem && onReEdit(selectedItem)}
          >
            <Text style={styles.reEditText}>Edit Again</Text>
          </Pressable>
          
          <Pressable style={styles.shareBtn} onPress={() => {}}>
             <Text style={styles.shareText}>Share Final</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0b0f1a',
  },
  safeArea: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    height: 60,
    borderBottomWidth: 1,
    borderBottomColor: '#1e293b',
  },
  headerBtn: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
  },
  previewSection: {
    flex: 1,
    padding: 20,
    justifyContent: 'center',
  },
  mainPreviewWrapper: {
    flex: 1,
    borderRadius: 16,
    overflow: 'hidden',
    backgroundColor: '#000',
    elevation: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 5 },
    shadowOpacity: 0.3,
    shadowRadius: 10,
  },
  mainPreview: {
    flex: 1,
  },
  listSection: {
    paddingVertical: 20,
  },
  listTitle: {
    color: '#94a3b8',
    fontSize: 13,
    fontWeight: '600',
    paddingHorizontal: 20,
    marginBottom: 12,
    textTransform: 'uppercase',
  },
  listContent: {
    paddingHorizontal: 16,
  },
  thumbContainer: {
    width: 80,
    height: 80,
    borderRadius: 12,
    marginHorizontal: 4,
    borderWidth: 2,
    borderColor: 'transparent',
    overflow: 'hidden',
    backgroundColor: '#1e293b',
  },
  activeThumb: {
    borderColor: '#3b82f6',
  },
  thumb: {
    width: '100%',
    height: '100%',
  },
  videoBadge: {
    position: 'absolute',
    top: 4,
    right: 4,
    backgroundColor: 'rgba(0,0,0,0.5)',
    width: 16,
    height: 16,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  videoBadgeText: {
    color: '#fff',
    fontSize: 8,
  },
  footer: {
    flexDirection: 'row',
    padding: 20,
    gap: 12,
  },
  reEditBtn: {
    flex: 1,
    backgroundColor: '#1e293b',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#334155',
  },
  reEditText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  shareBtn: {
    flex: 1,
    backgroundColor: '#3b82f6',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
  },
  shareText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
  },
  emptyView: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyText: {
    color: '#64748b',
    fontSize: 16,
  },
});
