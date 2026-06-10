import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Dimensions,
  PanResponder,
  Pressable,
  Image,
  ScrollView,
  Platform,
  Alert,
  Modal,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import type { MediaItem } from '../types';
import { editImage, trimVideo } from '../native/MediaEditor';
import { captureFrame } from '../native/FrameGrabber';
import { VideoPreview } from '../native/VideoPreview';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// --- Icons (View-based) ---
const HomeIcon = () => (
  <View style={iconStyles.homeContainer}>
    <View style={iconStyles.homeRoof} />
    <View style={iconStyles.homeBase} />
  </View>
);
const UndoIcon = () => (
  <View style={iconStyles.arrowContainer}>
    <Text style={iconStyles.arrowText}>⟲</Text>
  </View>
);
const RedoIcon = () => (
  <View style={iconStyles.arrowContainer}>
    <Text style={iconStyles.arrowText}>⟳</Text>
  </View>
);
const EyeIcon = () => (
  <View style={iconStyles.eyeContainer}>
    <View style={iconStyles.eyeOuter} />
    <View style={iconStyles.eyeInner} />
  </View>
);
const ShareIcon = () => (
  <View style={iconStyles.shareContainer}>
    <View style={iconStyles.shareArrow} />
    <View style={iconStyles.shareBox} />
  </View>
);
const ResetIcon = () => (
  <Text style={iconStyles.resetIconText}>↺</Text>
);
const FlipIcon = () => (
  <View style={iconStyles.flipContainer}>
    <View style={iconStyles.flipHalf} />
    <View style={[iconStyles.flipHalf, iconStyles.flipRight]} />
  </View>
);
const RotateIcon = () => (
  <Text style={iconStyles.rotateIconText}>↻</Text>
);
const ChevronDown = () => (
  <Text style={{ color: '#fff', fontSize: 10 }}>▼</Text>
);

const iconStyles = StyleSheet.create({
  homeContainer: { width: 24, height: 24, alignItems: 'center', justifyContent: 'center' },
  homeRoof: { width: 0, height: 0, borderLeftWidth: 10, borderRightWidth: 10, borderBottomWidth: 10, borderStyle: 'solid', backgroundColor: 'transparent', borderLeftColor: 'transparent', borderRightColor: 'transparent', borderBottomColor: '#fff', marginBottom: -2 },
  homeBase: { width: 16, height: 10, backgroundColor: '#fff', borderRadius: 1 },
  arrowContainer: { width: 24, height: 24, alignItems: 'center', justifyContent: 'center' },
  arrowText: { color: '#fff', fontSize: 20, fontWeight: 'bold' },
  eyeContainer: { width: 24, height: 24, alignItems: 'center', justifyContent: 'center' },
  eyeOuter: { width: 18, height: 10, borderRadius: 5, borderWidth: 2, borderColor: '#fff' },
  eyeInner: { position: 'absolute', width: 4, height: 4, borderRadius: 2, backgroundColor: '#fff' },
  shareContainer: { width: 24, height: 24, alignItems: 'center', justifyContent: 'center' },
  shareBox: { width: 14, height: 10, borderWidth: 2, borderColor: '#fff', borderTopWidth: 0, borderRadius: 1 },
  shareArrow: { width: 2, height: 14, backgroundColor: '#fff', position: 'absolute', top: 2 },
  resetIconText: { color: '#fff', fontSize: 18 },
  flipContainer: { width: 24, height: 20, flexDirection: 'row', gap: 2 },
  flipHalf: { flex: 1, backgroundColor: '#444', borderTopLeftRadius: 4, borderBottomLeftRadius: 4 },
  flipRight: { backgroundColor: '#fff', borderTopLeftRadius: 0, borderBottomLeftRadius: 0, borderTopRightRadius: 4, borderBottomRightRadius: 4 },
  rotateIconText: { color: '#fff', fontSize: 20 },
});

const ratios = [
  { label: 'Free', ratio: null },
  { label: 'Square', ratio: 1 },
  { label: '4:5', ratio: 4 / 5 },
  { label: '3:4', ratio: 3 / 4 },
  { label: '9:16', ratio: 9 / 16 },
  { label: '16:9', ratio: 16 / 9 },
  { label: '2:3', ratio: 2 / 3 },
  { label: '3:2', ratio: 3 / 2 },
];

interface CropScreenProps {
  item: MediaItem;
  onBack: () => void;
  onSave: (uri: string, thumb?: string, duration?: number) => void;
  aspectRatio?: '1:1' | '4:3' | '4:5' | '16:9' | '9:16' | 'free';
}
export function CropScreen({ item, onBack, onSave, aspectRatio = 'free' }: CropScreenProps) {
  const isRatioLocked = aspectRatio !== 'free';
  const getInitialRatioLabel = () => {
    if (!aspectRatio || aspectRatio === 'free') return 'Free';
    if (aspectRatio === '1:1') return 'Square';
    return aspectRatio; // '4:3', '4:5', '16:9', '9:16'
  };

  const [straightenAngle, setStraightenAngle] = useState(0);
  const [rotation, setRotation] = useState(0);
  const [selectedRatio, setSelectedRatio] = useState<string>(getInitialRatioLabel());
  const [isFixedRatio, setIsFixedRatio] = useState(isRatioLocked);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const [imageSize, setImageSize] = useState({ width: 0, height: 0 });
  const [mediaLayout, setMediaLayout] = useState({ x: 0, y: 0, width: 0, height: 0 });
  const [renderedImageSize, setRenderedImageSize] = useState({ width: 0, height: 0, top: 0, left: 0 });
  const renderedImageSizeRef = useRef(renderedImageSize);

  // Crop State
  const [cropBox, setCropBox] = useState({
    top: 50,
    left: 20,
    width: SCREEN_WIDTH - 40,
    height: 150,
  });

  const [resolution, setResolution] = useState({ w: 0, h: 0 });

  // REF-BASED BACKUP FOR PANRESPONDERS (Prevents closure traps)
  const cropBoxRef = useRef(cropBox);
  useEffect(() => {
    cropBoxRef.current = cropBox;
  }, [cropBox]);

  useEffect(() => {
    renderedImageSizeRef.current = renderedImageSize;
  }, [renderedImageSize]);

  useEffect(() => {
    if (item.type === 'image') {
      Image.getSize(item.uri, (w, h) => {
        setImageSize({ width: w, height: h });
      });
    } else {
      (async () => {
        try {
          const frameUri = await captureFrame(item.uri, { timeMs: 0 });
          Image.getSize(frameUri, (w, h) => {
            setImageSize({ width: w, height: h });
          });
        } catch {
          setImageSize({ width: 1080, height: 1920 });
        }
      })();
    }
  }, [item.uri, item.type]);

  // Calculate the actual area occupied by the image (contain)
  useEffect(() => {
    if (imageSize.width && mediaLayout.width) {
        const containerRatio = mediaLayout.width / mediaLayout.height;
        const isRotated = (rotation % 180 === 90);
        const imgW = isRotated ? imageSize.height : imageSize.width;
        const imgH = isRotated ? imageSize.width : imageSize.height;
        const imageRatio = imgW / imgH;

        let w, h;
        if (imageRatio > containerRatio) {
            w = mediaLayout.width;
            h = w / imageRatio;
        } else {
            h = mediaLayout.height;
            w = h * imageRatio;
        }

        const layoutW = isRotated ? h : w;
        const layoutH = isRotated ? w : h;
        const layoutL = (w - layoutW) / 2;
        const layoutT = (h - layoutH) / 2;

        const rendered = { 
            width: w, 
            height: h, 
            top: (mediaLayout.height - h) / 2, 
            left: (mediaLayout.width - w) / 2,
            imgW: layoutW,
            imgH: layoutH,
            imgL: layoutL,
            imgT: layoutT
        };
        
        setRenderedImageSize(rendered);
        
        setCropBox(() => {
            const ratioObj = ratios.find(r => r.label === selectedRatio);
            const ratio = ratioObj ? ratioObj.ratio : null;

            if (ratio) {
              let newWidth = rendered.width;
              let newHeight = newWidth / ratio;

              if (newHeight > rendered.height) {
                newHeight = rendered.height;
                newWidth = newHeight * ratio;
              }
              if (newWidth > rendered.width) {
                newWidth = rendered.width;
                newHeight = newWidth / ratio;
              }

              return {
                width: newWidth,
                height: newHeight,
                left: rendered.left + (rendered.width - newWidth) / 2,
                top: rendered.top + (rendered.height - newHeight) / 2,
              };
            } else {
              return {
                width: rendered.width,
                height: rendered.height,
                left: rendered.left,
                top: rendered.top,
              };
            }
        });
    }
  }, [imageSize, mediaLayout, rotation, selectedRatio]);


  const [flipX, setFlipX] = useState(false);
  const [flipY, setFlipY] = useState(false);

  const handleRatioSelect = (label: string, ratio: number | null) => {
    setSelectedRatio(label);
  };

  const updateResolution = () => {
    if (imageSize.width && renderedImageSize.width) {
      const isRotated = (rotation % 180 === 90);
      const pixelWidth = isRotated ? imageSize.height : imageSize.width;
      const scale = pixelWidth / renderedImageSize.width;
      setResolution({
        w: Math.round(cropBox.width * scale),
        h: Math.round(cropBox.height * scale)
      });
    }
  };

  useEffect(() => {
    updateResolution();
  }, [cropBox, renderedImageSize, rotation, imageSize]);

  const initialCrop = useRef({ top: 0, left: 0, width: 0, height: 0 }).current;

  const getClampedBox = (left: number, top: number, width: number, height: number) => {
    const rendered = renderedImageSizeRef.current;
    if (rendered.width === 0) return { left, top, width, height };

    const minSize = 60;
    const imageRight = rendered.left + rendered.width;
    const imageBottom = rendered.top + rendered.height;

    // 1. Clamp Position to the VIRTUAL CANVAS (not just original image)
    let l = Math.max(rendered.left, Math.min(left, imageRight - minSize));
    let t = Math.max(rendered.top, Math.min(top, imageBottom - minSize));

    // 2. Clamp Size to the VIRTUAL CANVAS
    let w = Math.max(minSize, Math.min(width, imageRight - l));
    let h = Math.max(minSize, Math.min(height, imageBottom - t));

    if (l + w > imageRight) l = imageRight - w;
    if (t + h > imageBottom) t = imageBottom - h;

    return { left: l, top: t, width: w, height: h };
  };

  const updateCrop = (newBox: { top: number; left: number; width: number; height: number }) => {
    setCropBox(getClampedBox(newBox.left, newBox.top, newBox.width, newBox.height));
  };

  const panMove = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onPanResponderGrant: () => {
        initialCrop.top = cropBoxRef.current.top;
        initialCrop.left = cropBoxRef.current.left;
        initialCrop.width = cropBoxRef.current.width;
        initialCrop.height = cropBoxRef.current.height;
      },
      onPanResponderMove: (_, gesture) => {
        const rendered = renderedImageSizeRef.current;
        let l = initialCrop.left + gesture.dx;
        let t = initialCrop.top + gesture.dy;

        l = Math.max(rendered.left, Math.min(l, rendered.left + rendered.width - initialCrop.width));
        t = Math.max(rendered.top, Math.min(t, rendered.top + rendered.height - initialCrop.height));

        setCropBox(prev => ({ ...prev, left: l, top: t }));
      },
      onPanResponderRelease: () => updateResolution()
    })
  ).current;

  const createSideResponder = (side: string) =>
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onPanResponderGrant: () => {
        initialCrop.top = cropBoxRef.current.top;
        initialCrop.left = cropBoxRef.current.left;
        initialCrop.width = cropBoxRef.current.width;
        initialCrop.height = cropBoxRef.current.height;
      },
      onPanResponderMove: (_, gesture) => {
        let { top, left, width, height } = initialCrop;
        if (side === 'left') {
          left += gesture.dx;
          width -= gesture.dx;
        } else if (side === 'right') {
          width += gesture.dx;
        }
        updateCrop({ top, left, width, height });
      },
      onPanResponderRelease: () => updateResolution()
    });

  const panLeft = useRef(createSideResponder('left')).current;
  const panRight = useRef(createSideResponder('right')).current;

  const createCornerResponder = (corner: string) =>
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onPanResponderGrant: () => {
        initialCrop.top = cropBoxRef.current.top;
        initialCrop.left = cropBoxRef.current.left;
        initialCrop.width = cropBoxRef.current.width;
        initialCrop.height = cropBoxRef.current.height;
      },
      onPanResponderMove: (_, gesture) => {
        let { top: t, left: l, width: w, height: h } = initialCrop;
        const ratio = ratios.find(r => r.label === selectedRatio)?.ratio;

        if (corner === 'TL') {
          t += gesture.dy;
          l += gesture.dx;
          w -= gesture.dx;
          h -= gesture.dy;
        } else if (corner === 'TR') {
          t += gesture.dy;
          w += gesture.dx;
          h -= gesture.dy;
        } else if (corner === 'BL') {
          l += gesture.dx;
          w -= gesture.dx;
          h += gesture.dy;
        } else if (corner === 'BR') {
          w += gesture.dx;
          h += gesture.dy;
        }

        if (ratio && isFixedRatio) {
          if (corner === 'BR' || corner === 'BL') h = w / ratio;
          else w = h * ratio;
        }

        updateCrop({ top: t, left: l, width: w, height: h });
      },
      onPanResponderRelease: () => updateResolution()
    });

  const panTL = useRef(createCornerResponder('TL')).current;
  const panTR = useRef(createCornerResponder('TR')).current;
  const panBL = useRef(createCornerResponder('BL')).current;
  const panBR = useRef(createCornerResponder('BR')).current;

  const handleSave = async () => {
    try {
      setSaving(true);
      if (!imageSize.width || !renderedImageSize.width) return;
      const isRotated = (rotation % 180 === 90);
      const pixelWidth = isRotated ? imageSize.height : imageSize.width;
      const scale = pixelWidth / renderedImageSize.width;

      const finalCrop = {
        x: Math.round((cropBox.left - renderedImageSize.left) * scale),
        y: Math.round((cropBox.top - renderedImageSize.top) * scale),
        width: Math.round(cropBox.width * scale),
        height: Math.round(cropBox.height * scale),
      };

      const options = {
        rotateDegrees: straightenAngle + rotation,
        flipX,
        flipY,
        crop: finalCrop,
        brightness: 0, contrast: 1, saturation: 1, grayscale: false,
      };

      const outUri = item.type === 'image'
        ? await editImage(item.uri, options)
        : await trimVideo(item.uri, { startMs: 0, endMs: item.durationMs || 10000, ...options });

      onSave(outUri, item.type === 'image' ? outUri : undefined, item.durationMs);
    } catch (err: any) {
      Alert.alert('Apply failed', err?.message ?? 'Could not process crop.');
    } finally {
      setSaving(false);
    }
  };

  const handleReset = () => {
    setStraightenAngle(0);
    setRotation(0);
    setFlipX(false);
    setFlipY(false);
    setSelectedRatio(getInitialRatioLabel());
    setIsFixedRatio(isRatioLocked);
  };

  const sliderPan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onPanResponderMove: (_, gesture) => {
        const delta = gesture.dx * 0.1;
        setStraightenAngle((prev) => Math.max(-45, Math.min(45, prev + delta)));
      },
    })
  ).current;

  const renderDial = () => {
    const marks = [];
    for (let i = -30; i <= 30; i++) {
      const isMajor = i % 5 === 0;
      const isCenter = i === 0;
      marks.push(
        <View
          key={i}
          style={[
            styles.dialMark,
            isMajor && styles.dialMarkLong,
            isCenter && styles.dialMarkCenter,
            Math.abs(i - straightenAngle / 2) < 0.5 && styles.dialMarkActive
          ]}
        />
      );
    }
    return marks;
  };

  return (
    <View style={styles.container}>
      <SafeAreaView style={styles.safeArea} edges={['left', 'right', 'bottom']}>
        <View style={styles.topBar}>
          <Pressable onPress={onBack} style={styles.topBtn}>
            <Text style={{ color: '#fff', fontSize: 16 }}>Cancel</Text>
          </Pressable>
          
          <View style={{ width: 60 }} />

          <View style={{ width: 60 }} />
        </View>

        <View style={styles.previewContainer}>
          <View
            style={styles.mediaContainer}
            onLayout={(e) => setMediaLayout(e.nativeEvent.layout)}
          >
             {renderedImageSize.width > 0 && (
                 <View style={{
                     position: 'absolute',
                     top: renderedImageSize.top,
                     left: renderedImageSize.left,
                     width: renderedImageSize.width,
                     height: renderedImageSize.height,
                     backgroundColor: '#000',
                 }}>
                    {item.type === 'video' ? (
                      <VideoPreview
                        uri={item.uri}
                        paused={false}
                        muted={true}
                        style={[
                            styles.media, 
                            { 
                              position: 'absolute',
                              top: (renderedImageSize as any).imgT,
                              left: (renderedImageSize as any).imgL,
                              width: (renderedImageSize as any).imgW,
                              height: (renderedImageSize as any).imgH,
                              transform: [
                                { rotate: `${rotation}deg` },
                                { rotate: `${straightenAngle}deg` },
                                { scaleX: flipX ? -1 : 1 },
                                { scaleY: flipY ? -1 : 1 }
                              ] 
                            }
                        ]}
                        resizeMode="contain"
                      />
                    ) : (
                      <Image 
                          source={{ uri: item.uri }} 
                          style={[
                              styles.media, 
                              { 
                                position: 'absolute',
                                top: (renderedImageSize as any).imgT,
                                left: (renderedImageSize as any).imgL,
                                width: (renderedImageSize as any).imgW,
                                height: (renderedImageSize as any).imgH,
                                transform: [
                                  { rotate: `${rotation}deg` },
                                  { rotate: `${straightenAngle}deg` },
                                  { scaleX: flipX ? -1 : 1 },
                                  { scaleY: flipY ? -1 : 1 }
                                ] 
                              }
                          ]} 
                          resizeMode="contain" 
                      />
                    )}
                 </View>
             )}

            <View style={[styles.shading, { top: renderedImageSize.top, left: renderedImageSize.left, width: renderedImageSize.width, height: cropBox.top - renderedImageSize.top }]} pointerEvents="none" />
            <View style={[styles.shading, { top: cropBox.top + cropBox.height, left: renderedImageSize.left, width: renderedImageSize.width, height: renderedImageSize.top + renderedImageSize.height - (cropBox.top + cropBox.height) }]} pointerEvents="none" />
            <View style={[styles.shading, { top: cropBox.top, left: renderedImageSize.left, width: cropBox.left - renderedImageSize.left, height: cropBox.height }]} pointerEvents="none" />
            <View style={[styles.shading, { top: cropBox.top, left: cropBox.left + cropBox.width, width: renderedImageSize.left + renderedImageSize.width - (cropBox.left + cropBox.width), height: cropBox.height }]} pointerEvents="none" />

            <View
              style={[styles.cropBox, {
                top: cropBox.top,
                left: cropBox.left,
                width: cropBox.width,
                height: cropBox.height,
                position: 'absolute'
              }]}
            >
              <View style={[StyleSheet.absoluteFill, { backgroundColor: 'transparent' }]} {...panMove.panHandlers} />
              <View style={[styles.gridV1, { pointerEvents: 'none' }]} />
              <View style={[styles.gridV2, { pointerEvents: 'none' }]} />
              <View style={[styles.gridH1, { pointerEvents: 'none' }]} />
              <View style={[styles.gridH2, { pointerEvents: 'none' }]} />
              <View style={[styles.corner, styles.cornerTL, { zIndex: 1000 }]} {...panTL.panHandlers}>
                <View style={[styles.cornerVisual, { borderTopWidth: 4, borderLeftWidth: 4 }]} />
              </View>
              <View style={[styles.corner, styles.cornerTR, { zIndex: 1000 }]} {...panTR.panHandlers}>
                <View style={[styles.cornerVisual, { borderTopWidth: 4, borderRightWidth: 4 }]} />
              </View>
              <View style={[styles.corner, styles.cornerBL, { zIndex: 1000 }]} {...panBL.panHandlers}>
                <View style={[styles.cornerVisual, { borderBottomWidth: 4, borderLeftWidth: 4 }]} />
              </View>
              <View style={[styles.corner, styles.cornerBR, { zIndex: 1000 }]} {...panBR.panHandlers}>
                <View style={[styles.cornerVisual, { borderBottomWidth: 4, borderRightWidth: 4 }]} />
              </View>
              <View style={[styles.sideHandle, styles.sideHandleLeft, { zIndex: 900 }]} {...panLeft.panHandlers} />
              <View style={[styles.sideHandle, styles.sideHandleRight, { zIndex: 900 }]} {...panRight.panHandlers} />
            </View>
          </View>
        </View>

        <View style={styles.bottomPanel}>

          <View style={styles.panelHeader}>
            <Pressable style={styles.resetBtn} onPress={handleReset}>
              <ResetIcon />
              <Text style={styles.resetText}>Reset</Text>
            </Pressable>
            <View style={styles.panelTitleContainer}>
              <Text style={styles.panelTitle}>Aspect Ratio</Text>
            </View>
            {!isRatioLocked ? (
              <Pressable style={[styles.fixedRatioBtn, isFixedRatio && styles.fixedRatioBtnActive]} onPress={() => setIsFixedRatio(!isFixedRatio)}>
                <Text style={styles.fixedRatioText}>{isFixedRatio ? 'Locked' : 'Unlocked'}</Text>
              </Pressable>
            ) : (
              <View style={[styles.fixedRatioBtn, styles.fixedRatioBtnActive, { opacity: 0.7 }]}>
                <Text style={styles.fixedRatioText}>Locked</Text>
              </View>
            )}
          </View>

          {/* Straighten Control */}
          <View style={styles.straightenContainer}>
            <View style={styles.sliderWrapper}>
              <Pressable
                style={[styles.flipBtn, (flipX || flipY) && { backgroundColor: '#333', borderRadius: 8 }]}
                onPress={() => setFlipX(!flipX)}
                onLongPress={() => setFlipY(!flipY)}
              >
                <FlipIcon />
              </Pressable>
              <View style={styles.dialContainer} {...sliderPan.panHandlers}>
                <View style={styles.dialCenterLine} />
                <View style={styles.dialMarksWrapper}>
                  {renderDial()}
                </View>
              </View>
              <Pressable style={styles.rotateBtn} onPress={() => setRotation(r => (r + 90) % 360)}>
                <RotateIcon />
              </Pressable>
            </View>
          </View>

          {/* Ratio Selector */}
          {!isRatioLocked && (
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.ratioScroll} contentContainerStyle={styles.ratioContent}>
              {ratios.map((r) => {
                const isSelected = selectedRatio === r.label;
                const boxRatio = r.ratio || 1;
                // Limit box size for icon
                const boxStyle = {
                  width: boxRatio > 1 ? 24 : 24 * boxRatio,
                  height: boxRatio > 1 ? 24 / boxRatio : 24,
                  borderWidth: 1.5,
                  borderColor: isSelected ? '#4A8CFF' : '#666',
                  borderRadius: 2,
                };

                return (
                  <Pressable key={r.label} style={styles.ratioItem} onPress={() => handleRatioSelect(r.label, r.ratio)}>
                    <View style={[styles.ratioIconBox, isSelected && styles.ratioIconBoxActive]}>
                      <View style={boxStyle} />
                    </View>
                    <Text style={[styles.ratioLabel, isSelected && styles.ratioLabelActive]}>{r.label}</Text>
                  </Pressable>
                );
              })}
            </ScrollView>
          )}

          {/* Footer Status with Save Button */}
          <View style={styles.footerStatus}>
            <View style={styles.footerLeft}>
              <Text style={styles.resolutionText}>{resolution.w} × {resolution.h} px</Text>
            </View>

            <Pressable onPress={handleSave} style={styles.primarySaveBtn} disabled={saving}>
              {saving ? <Text style={styles.saveText}>Applying...</Text> : <Text style={styles.saveText}>Apply Crop</Text>}
            </Pressable>
          </View>
        </View>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  safeArea: {
    flex: 1,
  },
  quickActions: {
    flexDirection: 'row',
    gap: 12,
  },
  quickActionBtn: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 15,
    backgroundColor: '#1a1a1a',
    borderWidth: 1,
    borderColor: '#333',
  },
  quickActionBtnActive: {
    backgroundColor: '#fff',
    borderColor: '#fff',
  },
  quickActionText: {
    color: '#999',
    fontSize: 10,
    fontWeight: '800',
  },
  quickActionTextActive: {
    color: '#000',
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    height: 56,
  },
  topBtn: {
    padding: 8,
  },
  saveText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
  },
  primarySaveBtn: {
    backgroundColor: '#4A8CFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 12,
  },
  previewContainer: {
    flex: 1,
    backgroundColor: '#000',
    justifyContent: 'center',
    alignItems: 'center',
  },
  mediaContainer: {
    flex: 1, // Full flexible space
    width: SCREEN_WIDTH,
    justifyContent: 'center',
    alignItems: 'center',
  },
  media: {
    width: '100%',
    height: '100%',
  },
  cropBox: {
    position: 'absolute',
    borderWidth: 1,
    borderColor: '#4A8CFF',
    backgroundColor: 'transparent',
  },
  gridV1: {
    position: 'absolute',
    left: '33.3%',
    top: 0,
    bottom: 0,
    width: 0.5,
    backgroundColor: 'rgba(255,255,255,0.5)',
  },
  gridV2: {
    position: 'absolute',
    left: '66.6%',
    top: 0,
    bottom: 0,
    width: 0.5,
    backgroundColor: 'rgba(255,255,255,0.5)',
  },
  gridH1: {
    position: 'absolute',
    top: '33.3%',
    left: 0,
    right: 0,
    height: 0.5,
    backgroundColor: 'rgba(255,255,255,0.5)',
  },
  gridH2: {
    position: 'absolute',
    top: '66.6%',
    left: 0,
    right: 0,
    height: 0.5,
    backgroundColor: 'rgba(255,255,255,0.5)',
  },
  corner: {
    position: 'absolute',
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 100,
  },
  shading: {
    position: 'absolute',
    backgroundColor: 'rgba(0,0,0,0.6)',
  },
  cornerVisual: {
    width: 20,
    height: 20,
    borderColor: '#4A8CFF',
  },
  cornerTL: {
    top: -10,
    left: -10,
  },
  cornerTR: {
    top: -10,
    right: -10,
  },
  cornerBL: {
    bottom: -10,
    left: -10,
  },
  cornerBR: {
    bottom: -10,
    right: -10,
  },
  sideHandle: {
    position: 'absolute',
    width: 10,
    height: 30,
    backgroundColor: '#4A8CFF',
    borderRadius: 2,
    zIndex: 90,
  },
  sideHandleLeft: {
    left: -2,
    top: '50%',
    marginTop: -10,
  },
  sideHandleRight: {
    right: -2,
    top: '50%',
    marginTop: -10,
  },
  bottomPanel: {
    backgroundColor: '#111',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    paddingBottom: Platform.OS === 'ios' ? 20 : 10,
  },
  panelHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  resetBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  resetText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '500',
  },
  panelTitleContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  panelTitle: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
  straightenContainer: {
    alignItems: 'center',
    paddingVertical: 10,
  },
  straightenText: {
    color: '#999',
    fontSize: 12,
    marginBottom: 10,
  },
  sliderWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    width: '100%',
    paddingHorizontal: 20,
    gap: 12,
  },
  flipBtn: {
    padding: 8,
  },
  rotateBtn: {
    padding: 8,
  },
  dialContainer: {
    flex: 1,
    height: 40,
    backgroundColor: '#222',
    borderRadius: 12,
    overflow: 'hidden',
    justifyContent: 'center',
    alignItems: 'center',
  },
  dialCenterLine: {
    position: 'absolute',
    top: 5,
    bottom: 5,
    width: 2,
    backgroundColor: '#fff',
    zIndex: 10,
  },
  dialMarksWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  dialMark: {
    width: 1,
    height: 8,
    backgroundColor: '#444',
  },
  dialMarkLong: {
    height: 14,
    backgroundColor: '#666',
  },
  dialMarkCenter: {
    backgroundColor: '#fff',
    height: 18,
    width: 2,
  },
  dialMarkActive: {
    backgroundColor: '#fff',
  },
  ratioScroll: {
    marginTop: 20,
  },
  ratioContent: {
    paddingHorizontal: 16,
    gap: 20,
  },
  ratioItem: {
    alignItems: 'center',
    gap: 6,
    width: 50,
  },
  ratioIconBox: {
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
    borderRadius: 8,
    backgroundColor: 'transparent',
  },
  ratioIconBoxActive: {
    backgroundColor: '#333',
  },
  ratioIcon: {
    fontSize: 20,
    color: '#fff',
  },
  ratioLabel: {
    color: '#666',
    fontSize: 12,
  },
  ratioLabelActive: {
    color: '#fff',
    fontWeight: '600',
  },
  footerStatus: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderTopWidth: 0.5,
    borderTopColor: '#222',
    marginTop: 10,
  },
  footerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  footerIcon: {
    fontSize: 18,
  },
  footerText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '500',
  },
  footerCenter: {
    flex: 1,
    alignItems: 'center',
  },
  resolutionText: {
    color: '#999',
    fontSize: 12,
  },
  fixedRatioBtn: {
    backgroundColor: '#222',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  fixedRatioBtnActive: {
    backgroundColor: '#333',
  },
  fixedRatioText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '500',
  },
});
