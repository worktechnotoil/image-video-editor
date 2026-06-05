import React from 'react';
import { requireNativeComponent, ViewStyle, StyleProp } from 'react-native';

type Props = {
  uri: string;
  paused?: boolean;
  muted?: boolean;
  style?: StyleProp<ViewStyle>;
  resizeMode?: string;
  trimStartMs?: number;
  trimEndMs?: number;
  seekToMs?: number;
  onChange?: (e: { nativeEvent: { currentTimeMs: number } }) => void;
};

const NativeVideoPreview = requireNativeComponent<Props>('RNVideoPreview');

export function VideoPreview(props: Props) {
  return <NativeVideoPreview {...props} />;
}
