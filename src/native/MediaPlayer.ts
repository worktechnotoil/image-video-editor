import { NativeModules, Platform } from 'react-native';

const { RNMediaPlayer } = NativeModules as {
  RNMediaPlayer?: {
    playVideo: (uri: string) => Promise<boolean>;
  };
};

export async function playVideo(uri: string): Promise<boolean> {
  if (!RNMediaPlayer?.playVideo) {
    throw new Error(
      `RNMediaPlayer is not available on ${Platform.OS}. Make sure the native module is linked.`
    );
  }
  return RNMediaPlayer.playVideo(uri);
}
