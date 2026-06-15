import React, { useState } from 'react';
import { Alert, StatusBar, useColorScheme, View, Text, ActivityIndicator } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { PickScreen } from '../screens/PickScreen';
import { CropScreen } from '../screens/CropScreen';
import { EditorScreen } from '../screens/EditorScreen';
import { ExportScreen } from '../screens/ExportScreen';
import { exportAsset } from '../native/MediaLibrary';
import type { MediaItem, MusicTrack } from '../types';
import Ionicons from 'react-native-vector-icons/Ionicons';

Ionicons.loadFont().catch(() => {});

export interface VideoEditorProps {
  onClose?: () => void;
  onFinishExport?: (
    editedMedia: Record<string, MediaItem>,
    paths: string[],
    editedArray: MediaItem[],
    cameraMode?: string,
    globalMusic?: MusicTrack
  ) => void;
  headerTitle?: string;
  customCancelIcon?: React.ReactNode;
  onCancelPress?: () => void;
  cameraModes?: string[];
  defaultCameraMode?: string;
  musicList?: MusicTrack[];
  /** Maximum number of media items user can select. Default: 1, Max allowed: 5 */
  maxSelection?: number;
  /**
   * Enforce a fixed aspect ratio for image/video preview.
   * '1:1' = Square, '4:3' = Standard, '4:5' = Instagram Portrait,
   * '16:9' = Landscape, '9:16' = Portrait, 'free' = No restriction (default)
   */
  aspectRatio?: '1:1' | '4:3' | '4:5' | '16:9' | '9:16' | 'free';
  /**
   * Maximum video duration allowed (in milliseconds).
   */
  maxVideoDurationMs?: number;
  /** Filter the media type that can be picked. Default: 'any' */
  mediaType?: 'photo' | 'video' | 'any';
  /** Control which tabs are shown in the picker. Default: ['GALLERY', 'PHOTO', 'VIDEO'] */
  mediaTabs?: ('GALLERY' | 'PHOTO' | 'VIDEO')[];
}

export default function VideoEditor({
  onClose,
  onFinishExport,
  headerTitle,
  customCancelIcon,
  onCancelPress,
  cameraModes,
  defaultCameraMode,
  musicList,
  maxSelection = 1,
  aspectRatio = 'free',
  maxVideoDurationMs,
  mediaType = 'any',
  mediaTabs = ['GALLERY', 'PHOTO', 'VIDEO'],
}: VideoEditorProps) {
  const clampedMax = Math.min(5, Math.max(1, maxSelection));
  const isDarkMode = useColorScheme() === 'dark';
  const [screen, setScreen] = useState<'pick' | 'editor' | 'crop' | 'export'>('pick');
  const [items, setItems] = useState<MediaItem[]>([]);
  const [current, setCurrent] = useState<MediaItem | null>(null);
  const [editedMedia, setEditedMedia] = useState<Record<string, MediaItem>>({});
  const [originals, setOriginals] = useState<Record<string, MediaItem>>({});
  const [selectedCameraMode, setSelectedCameraMode] = useState<string>(defaultCameraMode || 'STORY');
  const [processing, setProcessing] = useState(false);
  const [exportCache, setExportCache] = useState<Record<string, string>>({});

  const ensureExported = async (item: MediaItem, ignoreEdits = false): Promise<MediaItem> => {
    console.log(`[ensureExported] Start for item: ${item.id}, uri: ${item.uri}`);
    if (!ignoreEdits && editedMedia[item.id]) {
      console.log(`[ensureExported] Found in editedMedia! Returning early.`);
      return editedMedia[item.id];
    }
    if (exportCache[item.id]) {
      console.log(`[ensureExported] Found in exportCache! Returning cached URI: ${exportCache[item.id]}`);
      return { ...item, uri: exportCache[item.id] };
    }
    if (!item.uri.startsWith('ph://') && !item.uri.startsWith('content://')) {
      console.log(`[ensureExported] URI is already local file, skipping native export.`);
      return item;
    }
    try {
      console.log(`[ensureExported] Calling native exportAsset...`);
      const fileUri = await exportAsset(item.id);
      console.log(`[ensureExported] Native export success! New URI: ${fileUri}`);
      setExportCache(prev => ({ ...prev, [item.id]: fileUri }));
      return { ...item, uri: fileUri };
    } catch (err: any) {
      console.error('[ensureExported] ASSET EXPORT FROM LIBRARY FAILED:', err?.message ?? err);
      return item;
    }
  };

  return (
    <SafeAreaProvider>
      <SafeAreaView style={{ flex: 1, backgroundColor: '#0b0f1a' }} edges={['top', 'bottom', 'left', 'right']}>
        <StatusBar
          barStyle="light-content"
          backgroundColor="transparent"
          translucent={true}
        />
        <View style={{ flex: 1, display: screen === 'pick' ? 'flex' : 'none' }}>
          <PickScreen
            isActive={screen === 'pick'}
            items={items}
            headerTitle={headerTitle}
            customCancelIcon={customCancelIcon}
            onCancelPress={onCancelPress || onClose}
            cameraModes={cameraModes}
            defaultCameraMode={defaultCameraMode}
            maxSelection={clampedMax}
            aspectRatio={aspectRatio}
            onCameraModeChange={(mode) => {
              setSelectedCameraMode(mode);
            }}
            mediaType={mediaType}
            mediaTabs={mediaTabs}
            onPicked={(picked: MediaItem[]) => {
              // Save originals for "Fresh Start" editing
              const newOriginals = { ...originals };
              picked.forEach(p => {
                if (!newOriginals[p.id]) newOriginals[p.id] = p;
              });
              setOriginals(newOriginals);

              setItems(picked);
            }}
            onNext={async (picked) => {
              console.log(`[onNext] Triggered with ${picked?.length} items`);
              if (processing) {
                console.log(`[onNext] Aborting, already processing!`);
                return;
              }
              if (!picked || picked.length === 0) {
                console.log(`[onNext] Aborting, picked is empty!`);
                return;
              }
              console.log(`[onNext] Setting processing=true`);
              setProcessing(true);
              
              try {
                console.log(`[onNext] Starting Promise.all for ${picked.length} items`);
                const resolvedItems = await Promise.all(
                  picked.map(item => ensureExported(item, false))
                );
                
                console.log(`[onNext] Promise.all completed! Updating state...`);
                setItems(resolvedItems);
                setCurrent(resolvedItems[0]);
                setScreen('editor');
                console.log(`[onNext] Screen set to editor`);
              } catch (e) {
                console.error(`[onNext] Promise.all threw an error!`, e);
              } finally {
                console.log(`[onNext] Finally block - setting processing=false`);
                setProcessing(false);
              }
            }}
          />
          {processing && (
            <View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'center', alignItems: 'center' }}>
              <ActivityIndicator size="large" color="#ffffff" />
            </View>
          )}
        </View>
        {screen === 'editor' && current && (
           <EditorScreen 
            items={items}
            initialIndex={Math.max(0, items.findIndex(it => it.id === current.id))}
            maxVideoDurationMs={maxVideoDurationMs}
            onBack={() => {
              setEditedMedia({});
              const restoredItems = items.map(item => originals[item.id] || item);
              setItems(restoredItems);
              if (onClose) {
                onClose();
              } else {
                setScreen('pick');
              }
            }}
            onSaved={(updatedItems) => {
              const newEditedMedia = { ...editedMedia };
              const paths: string[] = [];
              
              updatedItems.forEach(item => {
                newEditedMedia[item.id] = item;
                paths.push(item.uri);
              });
              
              setEditedMedia(newEditedMedia);
              setItems(updatedItems);

              if (onFinishExport) {
                onFinishExport(newEditedMedia, paths, updatedItems, selectedCameraMode);
              }
              
              // Do not show the export screen, reset to pick screen
              setScreen('pick');
            }}
            onOpenCrop={(item) => {
              setCurrent(item);
              setScreen('crop');
            }}
            musicList={musicList}
           />
        )}
        {screen === 'crop' && current && (
          <CropScreen
            item={current}
            aspectRatio={aspectRatio}
            maxVideoDurationMs={maxVideoDurationMs}
            onBack={() => setScreen('editor')}
            onSave={(uri, thumbnailUri, durationMs) => {
              const updated = {
                ...current,
                uri,
                thumbnailUri: thumbnailUri ?? current.thumbnailUri,
                durationMs: durationMs ?? current.durationMs
              };

              setEditedMedia((prev: Record<string, MediaItem>) => ({ ...prev, [current.id]: updated }));

              setItems((prev: MediaItem[]) =>
                prev.map((it) => it.id === current.id ? updated : it)
              );

              setCurrent(updated);
              setScreen('editor');
            }}
          />
        )}
        {screen === 'export' && (
          <ExportScreen 
            editedMedia={editedMedia}
            onHome={() => {
              setEditedMedia({});
              setScreen('pick');
            }}
            onReEdit={(item) => {
                setCurrent(item);
                setScreen('editor');
            }}
          />
        )}
      </SafeAreaView>
    </SafeAreaProvider>
  );
}
