import React, { useState } from 'react';
import { Alert, StatusBar, useColorScheme } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { PickScreen } from '../screens/PickScreen';
import { CropScreen } from '../screens/CropScreen';
import { EditorScreen } from '../screens/EditorScreen';
import { ExportScreen } from '../screens/ExportScreen';
import { exportAsset } from '../native/MediaLibrary';
import type { MediaItem, MusicTrack } from '../types';

export interface VideoEditorProps {
  onClose?: () => void;
  onFinishExport?: (
    editedMedia: Record<string, MediaItem>,
    paths: string[],
    editedArray: MediaItem[],
    cameraMode?: string
  ) => void;
  headerTitle?: string;
  customCancelIcon?: React.ReactNode;
  onCancelPress?: () => void;
  cameraModes?: string[];
  defaultCameraMode?: string;
  musicList?: MusicTrack[];
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
}: VideoEditorProps) {
  const isDarkMode = useColorScheme() === 'dark';
  const [screen, setScreen] = useState<'pick' | 'editor' | 'crop' | 'export'>('pick');
  const [items, setItems] = useState<MediaItem[]>([]);
  const [current, setCurrent] = useState<MediaItem | null>(null);
  const [editedMedia, setEditedMedia] = useState<Record<string, MediaItem>>({});
  const [originals, setOriginals] = useState<Record<string, MediaItem>>({});
  const [selectedCameraMode, setSelectedCameraMode] = useState<string>(defaultCameraMode || 'STORY');

  const ensureExported = async (item: MediaItem, ignoreEdits = false): Promise<MediaItem> => {
    if (!ignoreEdits && editedMedia[item.id]) {
      return editedMedia[item.id];
    }
    if (!item.uri.startsWith('ph://') && !item.uri.startsWith('content://')) {
      return item;
    }
    try {
      const fileUri = await exportAsset(item.id);
      return { ...item, uri: fileUri };
    } catch (err: any) {
      console.error('ASSET EXPORT FROM LIBRARY FAILED:', err?.message ?? err);
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
        {screen === 'pick' && (
          <PickScreen
            items={items}
            headerTitle={headerTitle}
            customCancelIcon={customCancelIcon}
            onCancelPress={onCancelPress || onClose}
            cameraModes={cameraModes}
            defaultCameraMode={defaultCameraMode}
            onCameraModeChange={(mode) => {
              setSelectedCameraMode(mode);
            }}
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
              if (!picked || picked.length === 0) {
                return;
              }
              const resolvedItems = await Promise.all(
                picked.map(item => ensureExported(item, false))
              );
              setItems(resolvedItems);
              setCurrent(resolvedItems[0]);
              setScreen('editor');
            }}
          />
        )}
        {screen === 'editor' && current && (
           <EditorScreen 
            items={items}
            initialIndex={Math.max(0, items.findIndex(it => it.id === current.id))}
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
