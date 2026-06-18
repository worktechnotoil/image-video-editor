# @technotoil/image-video-editor

A high-performance, feature-rich React Native image and video editor. This library packages video trimming, custom image overlay frames, audio mix, native iOS/Android camera, and video filter features into a single, cohesive standalone component.

## Features
* 📹 **Native Camera View**: High-performance thread-safe AVCaptureSession wrapper for iOS and custom camera on Android.
* ✂️ **Video Trimming**: Seamless interactive trimming of video files.
* 🖼️ **Custom Photo Frames**: Layer beautiful custom frames on top of images.
* 🎵 **Audio Mixing & Carousel Sync**: Add background music tracks to your videos. Applies custom audio seamlessly across all videos in a multi-item carousel, automatically pausing original video sound.
* 📦 **Modular Export**: Triggers callbacks with local filesystem URIs suitable for server uploads.
* 📱 **Multi-Select & Swiping**: Select up to 5 items simultaneously and edit them smoothly via horizontal swiping. UI state and trimming configurations perfectly sync across items.

---

## Installation

Add the library to your React Native project:

```bash
yarn add @technotoil/image-video-editor
# or
npm install @technotoil/image-video-editor
```

Ensure the peer dependencies are installed:

```bash
yarn add react-native-image-crop-picker react-native-safe-area-context react-native-video
```

### Native Setup

#### iOS Installation
Run pod install in your `ios` directory:
```bash
cd ios && pod install
```

Ensure the following keys are added to your `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to record videos and take photos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone to record audio for videos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to pick and save media files.</string>
```

#### Android Installation
Make sure to add the FFmpeg kit dependency in your app's `android/app/build.gradle`:
```groovy
dependencies {
    implementation("com.arthenica:ffmpeg-kit-full-gpl:6.0-2")
}
```

Add permissions in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

---

## Quick Example (onPress Modal Integration)

The editor is designed to launch cleanly from a button action and output the video URL when exported.

```tsx
import React, { useState } from 'react';
import { View, Button, Modal, StyleSheet } from 'react-native';
import { VideoEditor } from '@technotoil/image-video-editor';

export default function App() {
  const [editorVisible, setEditorVisible] = useState(false);

  return (
    <View style={styles.container}>
      <Button 
        title="Open Video Editor" 
        onPress={() => setEditorVisible(true)} 
      />

      <Modal
        visible={editorVisible}
        animationType="slide"
        onRequestClose={() => setEditorVisible(false)}
      >
        <VideoEditor
          headerTitle="Create New Post"
          cameraModes={['POST', 'STORY', 'REEL']}
          defaultCameraMode="REEL"
          mediaType="any"
          mediaTabs={['GALLERY', 'PHOTO', 'VIDEO']}
          maxVideoDurationMs={30000} // Force trim videos longer than 30s
          onCancelPress={() => setEditorVisible(false)}
          onFinishExport={(editedMedia, paths, editedArray, cameraMode) => {
            console.log('Export completed successfully!');
            console.log('Exported File Paths:', paths); // array of video/image URLs
            
            // Perform your server upload here:
            // uploadToServer(paths[0]);

            setEditorVisible(false);
          }}
        />
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
});
```

## Props API

| Prop | Type | Default | Description |
|---|---|---|---|
| `headerTitle` | `string` | `"New post"` | Title text displayed in the header. |
| `cameraModes` | `Array<'POST' \| 'STORY' \| 'REEL'>` | `['POST', 'STORY', 'REEL']` | Active shooting modes allowed. |
| `defaultCameraMode` | `'POST' \| 'STORY' \| 'REEL'` | `"REEL"` | Initial shooting mode when opening. |
| `musicList` | `MusicTrack[]` | `[]` | List of audio tracks available to overlay on videos. |
| `maxSelection` | `number` | `1` | Maximum number of media items user can select. Max allowed is 5. |
| `aspectRatio` | `'1:1' \| '4:3' \| '4:5' \| '16:9' \| '9:16' \| 'free'` | `'free'` | Enforce a fixed aspect ratio for image/video preview. |
| `mediaType` | `'photo' \| 'video' \| 'any'` | `'any'` | Filter the library to only show photos, videos, or both. |
| `mediaTabs` | `Array<'GALLERY' \| 'PHOTO' \| 'VIDEO'>` | `['GALLERY', 'PHOTO', 'VIDEO']` | Control which selection tabs are visible at the bottom of the picker screen. Defaults to the first array item. |
| `maxVideoDurationMs` | `number` | `undefined` | Maximum video duration allowed in milliseconds. If a video exceeds this, the trim editor will automatically force the user to trim. |
| `onCancelPress` | `() => void` | `undefined` | Callback fired when user cancels or leaves the editor. |
| `onFinishExport` | `(editedMedia: any, paths: string[], editedArray: any[], cameraMode: string) => void` | `undefined` | Fired when edits finish exporting. Fills `paths` with target video/image file URIs. |

---

## License

MIT
