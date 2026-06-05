import React, { useState } from 'react';
import { StyleSheet, Text, View, TouchableOpacity, SafeAreaView, StatusBar, Image, ScrollView } from 'react-native';
import { VideoEditor } from '@technotoil/image-video-editor';

const DUMMY_MUSIC_LIST = [
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
  }
];

export default function App() {
  const [editorVisible, setEditorVisible] = useState(false);
  const [exportedResult, setExportedResult] = useState<{
    paths: string[];
    cameraMode: string;
    media: any[];
  } | null>(null);

  const handleFinishExport = (editedMedia: any, paths: string[], editedArray: any[], cameraMode: string) => {
    console.log('App.tsx - Export completed!');
    console.log('Exported Paths:', paths);
    console.log('Selected Camera Mode:', cameraMode);
    
    setExportedResult({
      paths,
      cameraMode,
      media: editedArray || [editedMedia]
    });
    setEditorVisible(false);
  };

  if (editorVisible) {
    return (
      <View style={styles.fullscreen}>
        <StatusBar barStyle="light-content" backgroundColor="#000" />
        <VideoEditor
          headerTitle="New post"
          cameraModes={['POST', 'STORY', 'REEL']}
          defaultCameraMode="REEL"
          onCancelPress={() => setEditorVisible(false)}
          onFinishExport={handleFinishExport}
          musicList={DUMMY_MUSIC_LIST}
        />
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#121212" />
      <View style={styles.header}>
        <Text style={styles.headerTitle}>TechnoToil Editor Demo</Text>
        <Text style={styles.headerSubtitle}>v0.1.0 Example App</Text>
      </View>

      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.heroSection}>
          <Text style={styles.heroTitle}>Premium Video & Image Editor</Text>
          <Text style={styles.heroDesc}>
            Fully integrated camera, video trimmer, custom image overlays, audio mix, and real-time filters.
          </Text>
        </View>

        <TouchableOpacity 
          style={styles.launchButton} 
          activeOpacity={0.8}
          onPress={() => setEditorVisible(true)}
        >
          <Text style={styles.launchButtonText}>Launch Video Editor</Text>
        </TouchableOpacity>

        {exportedResult && (
          <View style={styles.resultCard}>
            <Text style={styles.resultTitle}>Last Export Result</Text>
            <View style={styles.resultMetaRow}>
              <Text style={styles.metaLabel}>Camera Mode:</Text>
              <Text style={styles.metaValue}>{exportedResult.cameraMode}</Text>
            </View>
            
            <Text style={styles.metaLabel}>Exported File URLs (Ready for Upload):</Text>
            {exportedResult.paths.map((path, idx) => (
              <View key={idx} style={styles.pathItem}>
                <Text style={styles.pathText} numberOfLines={2} ellipsizeMode="head">
                  {path}
                </Text>
              </View>
            ))}

            {exportedResult.media && exportedResult.media.length > 0 && (
              <View style={styles.thumbnailContainer}>
                <Text style={styles.metaLabel}>Exported Assets Preview:</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.thumbScroll}>
                  {exportedResult.media.map((med, index) => (
                    <View key={index} style={styles.thumbWrapper}>
                      <Image source={{ uri: med.uri }} style={styles.thumbImage} />
                      <View style={styles.typeBadge}>
                        <Text style={styles.typeBadgeText}>
                          {med.type?.toUpperCase() || 'MEDIA'}
                        </Text>
                      </View>
                    </View>
                  ))}
                </ScrollView>
              </View>
            )}
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  fullscreen: {
    flex: 1,
    backgroundColor: '#000',
  },
  container: {
    flex: 1,
    backgroundColor: '#121212',
  },
  header: {
    paddingHorizontal: 24,
    paddingTop: 16,
    paddingBottom: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#222',
  },
  headerTitle: {
    color: '#fff',
    fontSize: 20,
    fontWeight: '800',
    letterSpacing: 0.5,
  },
  headerSubtitle: {
    color: '#888',
    fontSize: 12,
    marginTop: 2,
    fontWeight: '500',
  },
  scrollContent: {
    padding: 24,
    alignItems: 'center',
  },
  heroSection: {
    alignItems: 'center',
    marginVertical: 40,
  },
  heroTitle: {
    color: '#fff',
    fontSize: 24,
    fontWeight: '700',
    textAlign: 'center',
  },
  heroDesc: {
    color: '#aaa',
    fontSize: 14,
    textAlign: 'center',
    marginTop: 12,
    lineHeight: 22,
    paddingHorizontal: 16,
  },
  launchButton: {
    backgroundColor: '#ff3b30',
    width: '100%',
    height: 56,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#ff3b30',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 5,
    marginBottom: 40,
  },
  launchButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
    letterSpacing: 1,
  },
  resultCard: {
    backgroundColor: '#1e1e1e',
    width: '100%',
    borderRadius: 16,
    padding: 20,
    borderWidth: 1,
    borderBottomColor: '#333',
    borderColor: '#2d2d2d',
  },
  resultTitle: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 16,
  },
  resultMetaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  metaLabel: {
    color: '#888',
    fontSize: 12,
    fontWeight: '600',
    marginBottom: 6,
  },
  metaValue: {
    color: '#ff3b30',
    fontSize: 12,
    fontWeight: '700',
    marginLeft: 8,
    backgroundColor: '#2c1919',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 4,
  },
  pathItem: {
    backgroundColor: '#151515',
    padding: 12,
    borderRadius: 8,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#252525',
  },
  pathText: {
    color: '#4cd964',
    fontSize: 12,
    fontFamily: 'Courier',
  },
  thumbnailContainer: {
    marginTop: 8,
  },
  thumbScroll: {
    marginTop: 8,
  },
  thumbWrapper: {
    marginRight: 12,
    position: 'relative',
  },
  thumbImage: {
    width: 100,
    height: 100,
    borderRadius: 8,
    backgroundColor: '#2a2a2a',
  },
  typeBadge: {
    position: 'absolute',
    bottom: 6,
    left: 6,
    backgroundColor: 'rgba(0,0,0,0.6)',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  typeBadgeText: {
    color: '#fff',
    fontSize: 8,
    fontWeight: '700',
  },
});
