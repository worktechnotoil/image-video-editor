import { NativeModules, Platform } from 'react-native';
import type { MediaItem } from '../types';

const { RNMediaPicker } = NativeModules as {
  RNMediaPicker?: {
    pickMedia: () => Promise<MediaItem[]>;
  };
};

export async function pickMedia(): Promise<MediaItem[]> {
  if (!RNMediaPicker?.pickMedia) {
    throw new Error(
      `RNMediaPicker is not available on ${Platform.OS}. Make sure the native module is linked.`
    );
  }
  return RNMediaPicker.pickMedia();
}
