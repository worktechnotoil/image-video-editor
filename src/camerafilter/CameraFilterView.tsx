import React, { forwardRef, useImperativeHandle, useRef } from 'react';
import { requireNativeComponent, UIManager, findNodeHandle, type ViewProps, NativeModules, Platform } from 'react-native';
import type { FilterId } from './types';

export interface CameraFilterViewProps extends ViewProps {
  filter: FilterId;
  facing?: 'front' | 'back';
}

export interface CameraFilterViewRef {
  startRecording: () => Promise<void>;
  stopRecording: () => Promise<string>;
  capturePhoto: () => Promise<{ uri: string; width: number; height: number }>;
}

const { CameraFilterModule } = NativeModules;
const NativeCameraFilterView = requireNativeComponent<CameraFilterViewProps>('CameraFilterView');

export const CameraFilterView = forwardRef<CameraFilterViewRef, CameraFilterViewProps>((props, ref) => {
  const nativeRef = useRef(null);

  useImperativeHandle(ref, () => ({
    capturePhoto: async () => {
      const node = findNodeHandle(nativeRef.current) || -1;
      if (!CameraFilterModule) {
        return { uri: "file:///dummy_captured_photo.jpg", width: 720, height: 1280 };
      }
      const uri = await CameraFilterModule.capturePhoto(node);
      return {
        uri,
        width: 720,
        height: 1280
      };
    },
    startRecording: async () => {
      const node = findNodeHandle(nativeRef.current) || -1;
      if (!CameraFilterModule) return Promise.resolve();
      return CameraFilterModule.startRecording(node);
    },
    stopRecording: async () => {
      const node = findNodeHandle(nativeRef.current) || -1;
      if (!CameraFilterModule) return Promise.resolve("file:///dummy_recorded_path.mp4");
      return CameraFilterModule.stopRecording(node);
    }
  }));

  return <NativeCameraFilterView ref={nativeRef} {...props} />;
});
