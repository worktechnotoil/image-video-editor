import { NativeModules, Platform } from 'react-native';
import type { FrameCaptureOptions } from '../types';

const { RNFrameGrabber } = NativeModules as {
  RNFrameGrabber?: {
    captureFrame: (uri: string, options: FrameCaptureOptions) => Promise<string>;
  };
};

export async function captureFrame(
  uri: string,
  options: FrameCaptureOptions
): Promise<string> {
  if (!RNFrameGrabber?.captureFrame) {
    throw new Error(
      `RNFrameGrabber.captureFrame is not available on ${Platform.OS}. Make sure the native module is linked.`
    );
  }
  return RNFrameGrabber.captureFrame(uri, options);
}

