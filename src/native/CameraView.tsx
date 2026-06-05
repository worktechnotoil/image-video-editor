import React, { forwardRef, useImperativeHandle, useRef, useState } from 'react';
import { requireNativeComponent, ViewStyle } from 'react-native';

type NativeProps = {
  facing: 'front' | 'back';
  flashMode?: 'on' | 'off';
  style?: ViewStyle;
  photoTrigger?: string;
  recordTrigger?: string;
  onPhotoCaptured?: (event: any) => void;
  onRecordStarted?: (event: any) => void;
  onRecordStopped?: (event: any) => void;
};

const NativeCameraView = requireNativeComponent<NativeProps>('RNCameraView');

export interface CameraViewRef {
  capturePhoto(): Promise<{ uri: string; width: number; height: number }>;
  startRecording(): Promise<void>;
  stopRecording(): Promise<{ uri: string; durationMs: number; width: number; height: number }>;
}

interface Props {
  facing: 'front' | 'back';
  flashMode?: 'on' | 'off';
  style?: ViewStyle;
}

export const CameraView = forwardRef<CameraViewRef, Props>(({ facing, flashMode = 'off', style }, ref) => {
  const [photoTrigger, setPhotoTrigger] = useState<string>('');
  const [recordTrigger, setRecordTrigger] = useState<'start' | 'stop' | 'idle'>('idle');
  
  const photoPromiseRef = useRef<{ resolve: Function; reject: Function } | null>(null);
  const recordStartPromiseRef = useRef<{ resolve: Function; reject: Function } | null>(null);
  const recordStopPromiseRef = useRef<{ resolve: Function; reject: Function } | null>(null);

  useImperativeHandle(ref, () => ({
    capturePhoto: () => {
      return new Promise((resolve, reject) => {
        photoPromiseRef.current = { resolve, reject };
        setPhotoTrigger(Date.now().toString());
      });
    },
    startRecording: () => {
      return new Promise((resolve, reject) => {
        recordStartPromiseRef.current = { resolve, reject };
        setRecordTrigger('start');
      });
    },
    stopRecording: () => {
      return new Promise((resolve, reject) => {
        recordStopPromiseRef.current = { resolve, reject };
        setRecordTrigger('stop');
      });
    },
  }));

  return (
    <NativeCameraView
      facing={facing}
      flashMode={flashMode}
      style={style}
      photoTrigger={photoTrigger}
      recordTrigger={recordTrigger}
      onPhotoCaptured={(e: any) => {
        const { uri, width, height, error } = e.nativeEvent;
        if (error) {
          photoPromiseRef.current?.reject(new Error(error));
        } else {
          photoPromiseRef.current?.resolve({ uri, width, height });
        }
        photoPromiseRef.current = null;
      }}
      onRecordStarted={(e: any) => {
        const { error } = e.nativeEvent;
        if (error) {
          recordStartPromiseRef.current?.reject(new Error(error));
        } else {
          recordStartPromiseRef.current?.resolve();
        }
        recordStartPromiseRef.current = null;
      }}
      onRecordStopped={(e: any) => {
        const { uri, durationMs, width, height, error } = e.nativeEvent;
        if (error) {
          recordStopPromiseRef.current?.reject(new Error(error));
        } else {
          recordStopPromiseRef.current?.resolve({ uri, durationMs, width, height });
        }
        recordStopPromiseRef.current = null;
        setRecordTrigger('idle');
      }}
    />
  );
});
