import { NativeModules, Platform } from 'react-native';
import type { ImageEditOptions, VideoTrimOptions } from '../types';

const { RNMediaEditor } = NativeModules as {
  RNMediaEditor?: {
    editImage: (uri: string, options: ImageEditOptions) => Promise<string>;
    trimVideo: (uri: string, options: VideoTrimOptions) => Promise<string>;
  };
};

export async function editImage(
  uri: string,
  options: ImageEditOptions
): Promise<string> {
  if (!RNMediaEditor?.editImage) {
    throw new Error(
      `RNMediaEditor.editImage is not available on ${Platform.OS}. Make sure the native module is linked.`
    );
  }
  return RNMediaEditor.editImage(uri, options);
}

export async function trimVideo(
  uri: string,
  options: VideoTrimOptions
): Promise<string> {
  if (!RNMediaEditor?.trimVideo) {
    throw new Error(
      `RNMediaEditor.trimVideo is not available on ${Platform.OS}. Make sure the native module is linked.`
    );
  }
  return RNMediaEditor.trimVideo(uri, options);
}
