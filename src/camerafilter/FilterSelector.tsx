import React, { useState, useRef } from 'react';
import { Animated, Pressable, ScrollView, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { FILTER_CATALOG, type FilterId } from './types';

const CircularProgressRing = ({ progressAnim, size = 84, strokeWidth = 4, color = '#ef4444' }: { progressAnim: Animated.Value, size?: number, strokeWidth?: number, color?: string }) => {
  const rotateRight = progressAnim.interpolate({
    inputRange: [0, 0.5, 1],
    outputRange: ['-135deg', '45deg', '45deg']
  });

  const rotateLeft = progressAnim.interpolate({
    inputRange: [0, 0.5, 1],
    outputRange: ['-135deg', '-135deg', '45deg']
  });

  return (
    <View style={{ width: size, height: size, position: 'absolute', left: 0, top: 0 }}>
      {/* Right side half circle (0 to 50%) */}
      <View style={{ width: size / 2, height: size, position: 'absolute', right: 0, overflow: 'hidden' }}>
        <Animated.View style={{
          width: size, height: size, borderRadius: size / 2,
          borderWidth: strokeWidth, borderColor: color,
          position: 'absolute', left: -size / 2,
          borderLeftColor: 'transparent', borderBottomColor: 'transparent',
          transform: [{ rotate: rotateRight }]
        }} />
      </View>

      {/* Left side half circle (50% to 100%) */}
      <View style={{ width: size / 2, height: size, position: 'absolute', left: 0, overflow: 'hidden' }}>
        <Animated.View style={{
          width: size, height: size, borderRadius: size / 2,
          borderWidth: strokeWidth, borderColor: color,
          position: 'absolute', left: 0,
          borderLeftColor: 'transparent', borderBottomColor: 'transparent',
          transform: [{ rotate: rotateLeft }]
        }} />
      </View>
    </View>
  );
};

const GLASSES_SUBCATEGORIES: { id: FilterId; label: string; emoji: string }[] = [
  { id: 'glasses_classic', label: 'Classic', emoji: '🕶️' },
  { id: 'glasses_sun', label: 'Sunglasses', emoji: '🕶️' },
  { id: 'glasses_retro', label: 'Retro', emoji: '👓' },
  { id: 'glasses_heart', label: 'Heart', emoji: '❤️' },
  { id: 'glasses_sport', label: 'Sport', emoji: '⚡' },
];

const LIPSTICK_SUBCATEGORIES: { id: FilterId; label: string; emoji: string }[] = [
  { id: 'lipstick_red', label: 'Ruby Red', emoji: '💄' },
  { id: 'lipstick_pink', label: 'Pink Rose', emoji: '💄' },
  { id: 'lipstick_coral', label: 'Coral Peach', emoji: '💄' },
  { id: 'lipstick_plum', label: 'Plum Berry', emoji: '💄' },
];

const isGlassesFilter = (id: FilterId) => {
  return id === 'glasses' || id.startsWith('glasses_');
};

const isLipstickFilter = (id: FilterId) => {
  return id === 'lipstick' || id.startsWith('lipstick_');
};

interface Props {
  onSelect: (id: FilterId) => void;
  onCapturePress?: () => void;
  onCaptureLongPress?: () => void;
  onCapturePressOut?: () => void;
  isRecording?: boolean;
  recordingProgressAnim?: Animated.Value;
}

export function FilterSelector({ onSelect, onCapturePress, onCaptureLongPress, onCapturePressOut, isRecording, recordingProgressAnim }: Props): React.JSX.Element {
  const [selected, setSelected] = useState<FilterId>('none');
  const { width: screenWidth } = useWindowDimensions();
  const scrollViewRef = useRef<ScrollView>(null);

  React.useEffect(() => {
    setSelected('none');
    onSelect('none');
    scrollViewRef.current?.scrollTo({ x: 0, animated: false });
  }, []);

  const itemWidth = 80;
  const gap = 12;
  const snapInterval = itemWidth + gap;
  const sidePadding = screenWidth / 2 - itemWidth / 2;

  // Calculate exact offsets for robust snapping on Android & iOS
  const snapOffsets = ['none', ...FILTER_CATALOG].map((_, i) => i * snapInterval);

  const centerItem = (index: number) => {
    // Calculate the target scroll offset to center the item
    const targetScrollX = index * snapInterval;

    scrollViewRef.current?.scrollTo({
      x: Math.max(0, targetScrollX),
      animated: true,
    });
  };

  const handlePressItem = (id: FilterId, index: number, isActive: boolean) => {
    if (isActive) {
      onCapturePress?.();
    } else {
      setSelected(id);
      onSelect(id);
      centerItem(index);
    }
  };

  const handleLongPressItem = (id: FilterId, index: number, isActive: boolean) => {
    if (isActive) {
      onCaptureLongPress?.();
    } else {
      setSelected(id);
      onSelect(id);
      centerItem(index);
    }
  };

  const handlePressOutItem = () => {
    onCapturePressOut?.();
  };

  const handleScrollEnd = (e: any) => {
    const offsetX = e.nativeEvent.contentOffset.x;
    const index = Math.max(0, Math.min(FILTER_CATALOG.length, Math.round(offsetX / snapInterval)));

    const options = ['none', ...FILTER_CATALOG.map(f => f.id)];
    const newSelectedId = options[index] as FilterId;

    if (newSelectedId && newSelectedId !== selected) {
      if (newSelectedId === 'glasses') {
        setSelected('glasses_classic');
        onSelect('glasses_classic');
      } else if (newSelectedId === 'lipstick') {
        setSelected('lipstick_red');
        onSelect('lipstick_red');
      } else {
        setSelected(newSelectedId);
        onSelect(newSelectedId);
      }
    }
  };

  const getActiveLabel = () => {
    if (selected === 'none') {
      return 'Normal';
    }
    const option = FILTER_CATALOG.find((f) => f.id === selected);
    if (option) {
      return option.label;
    }
    if (isGlassesFilter(selected)) {
      const sub = GLASSES_SUBCATEGORIES.find((s) => s.id === selected);
      return sub ? `Glasses - ${sub.label}` : 'Glasses';
    }
    if (isLipstickFilter(selected)) {
      const sub = LIPSTICK_SUBCATEGORIES.find((s) => s.id === selected);
      return sub ? `Lipstick - ${sub.label}` : 'Lipstick';
    }
    return '';
  };

  const activeLabel = getActiveLabel();

  return (
    <View style={styles.container}>
      {activeLabel ? (
        <View style={styles.activeLabelContainer}>
          <Text style={styles.activeLabelText}>{activeLabel}</Text>
        </View>
      ) : null}

      {isGlassesFilter(selected) && (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.subChipRow}
        >
          {GLASSES_SUBCATEGORIES.map((subOpt) => {
            const isActive = subOpt.id === selected;
            return (
              <Pressable
                key={subOpt.id}
                onPress={() => {
                  if (isActive) {
                    onCapturePress?.();
                  } else {
                    setSelected(subOpt.id);
                    onSelect(subOpt.id);
                  }
                }}
                onLongPress={() => {
                  if (!isActive) {
                    setSelected(subOpt.id);
                    onSelect(subOpt.id);
                  }
                  onCaptureLongPress?.();
                }}
                onPressOut={() => {
                  onCapturePressOut?.();
                }}
                delayLongPress={200}
                style={[styles.subChip, isActive && styles.subChipActive]}
              >
                <Text style={styles.subEmoji}>{subOpt.emoji}</Text>
                <Text style={[styles.subLabel, isActive && styles.subLabelActive]}>{subOpt.label}</Text>
              </Pressable>
            );
          })}
        </ScrollView>
      )}

      {isLipstickFilter(selected) && (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.subChipRow}
        >
          {LIPSTICK_SUBCATEGORIES.map((subOpt) => {
            const isActive = subOpt.id === selected;
            return (
              <Pressable
                key={subOpt.id}
                onPress={() => {
                  if (isActive) {
                    onCapturePress?.();
                  } else {
                    setSelected(subOpt.id);
                    onSelect(subOpt.id);
                  }
                }}
                onLongPress={() => {
                  if (!isActive) {
                    setSelected(subOpt.id);
                    onSelect(subOpt.id);
                  }
                  onCaptureLongPress?.();
                }}
                onPressOut={() => {
                  onCapturePressOut?.();
                }}
                delayLongPress={200}
                style={[styles.subChip, isActive && styles.subChipActive]}
              >
                <Text style={styles.subEmoji}>{subOpt.emoji}</Text>
                <Text style={[styles.subLabel, isActive && styles.subLabelActive]}>{subOpt.label}</Text>
              </Pressable>
            );
          })}
        </ScrollView>
      )}

      <View style={styles.scrollWrapper}>
        <View style={styles.staticRingContainer} pointerEvents="none">
          <View style={[styles.staticRing, isRecording && styles.staticRingRecording]} />
          {isRecording && recordingProgressAnim && (
            <View style={{ position: 'absolute', top: -4, alignSelf: 'center', width: 84, height: 84, marginTop: -5 }}>
              <CircularProgressRing progressAnim={recordingProgressAnim} size={84} />
            </View>
          )}
        </View>

        <ScrollView
          ref={scrollViewRef}
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={[styles.chipRow, { paddingHorizontal: sidePadding }]}
          snapToOffsets={snapOffsets}
          snapToAlignment="center"
          decelerationRate="fast"
          disableIntervalMomentum={true}
          onMomentumScrollEnd={handleScrollEnd}
          onScrollEndDrag={handleScrollEnd}
          scrollEventThrottle={16}
        >
          <Pressable
            onPress={() => handlePressItem('none', 0, selected === 'none')}
            onLongPress={() => handleLongPressItem('none', 0, selected === 'none')}
            onPressOut={() => handlePressOutItem()}
            delayLongPress={200}
            style={styles.itemContainer}
          >
            <View style={styles.circle}>
              {selected === 'none' ? (
                <View style={[styles.captureButton, isRecording && styles.captureButtonRecording]} />
              ) : (
                <Text style={styles.emoji}>⚪️</Text>
              )}
            </View>
            <Text style={[styles.label, selected === 'none' && styles.labelActive]}>Normal</Text>
          </Pressable>

          {FILTER_CATALOG.map((option, index) => {
            const isActive =
              option.id === selected ||
              (option.id === 'glasses' && isGlassesFilter(selected)) ||
              (option.id === 'lipstick' && isLipstickFilter(selected));

            const targetId: FilterId =
              option.id === 'glasses' ? (isGlassesFilter(selected) ? selected : 'glasses_classic') :
                option.id === 'lipstick' ? (isLipstickFilter(selected) ? selected : 'lipstick_red') :
                  option.id;

            return (
              <Pressable
                key={option.id}
                onPress={() => handlePressItem(targetId, index + 1, isActive)}
                onLongPress={() => handleLongPressItem(targetId, index + 1, isActive)}
                onPressOut={() => handlePressOutItem()}
                delayLongPress={200}
                style={styles.itemContainer}
              >
                <View style={styles.circle}>
                  <Text style={styles.emoji}>{option.emoji}</Text>
                </View>
                <Text style={[styles.label, isActive && styles.labelActive]} numberOfLines={1}>
                  {option.label}
                </Text>
              </Pressable>
            );
          })}
        </ScrollView>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  activeLabelContainer: {
    alignSelf: 'center',
    backgroundColor: 'rgba(0,0,0,0.6)',
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 20,
    marginBottom: 16,
  },
  activeLabelText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: 'bold',
  },
  chipRow: {
    paddingBottom: 8,
    gap: 12,
  },
  itemContainer: {
    alignItems: 'center',
    width: 80,
    justifyContent: 'center',
  },
  circle: {
    width: 66,
    height: 66,
    borderRadius: 33,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2.5,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  circleActive: {
    // No longer used, replaced by staticRing
  },
  staticRingContainer: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    right: 0,
    alignItems: 'center',
    justifyContent: 'flex-start',
    zIndex: 10,
  },
  staticRing: {
    width: 84,
    height: 84,
    borderRadius: 42,
    borderColor: '#ffffff',
    borderWidth: 4,
    backgroundColor: 'transparent',
    marginTop: -9, // Fine tune alignment to match the 66x66 circle inside the scrollview
  },
  staticRingRecording: {
    borderColor: 'rgba(255, 0, 0, 0.4)',
  },
  scrollWrapper: {
    width: '100%',
    position: 'relative',
  },
  captureButton: {
    width: 66,
    height: 66,
    borderRadius: 33,
    backgroundColor: '#fff',
  },
  captureButtonRecording: {
    backgroundColor: '#ef4444',
    borderRadius: 8,
    width: 32,
    height: 32,
  },
  emoji: {
    fontSize: 32,
  },
  label: {
    color: 'rgba(255,255,255,0.7)',
    fontSize: 10,
    marginTop: 14,
    textAlign: 'center',
  },
  labelActive: {
    color: '#ffffff',
    fontWeight: '600',
  },
  subChipRow: {
    paddingHorizontal: 16,
    paddingBottom: 12,
    gap: 8,
  },
  subChip: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 14,
    backgroundColor: 'rgba(0,0,0,0.6)',
    gap: 4,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.15)',
  },
  subChipActive: {
    backgroundColor: 'rgba(255,255,255,0.95)',
    borderColor: 'rgba(255,255,255,0.95)',
  },
  subEmoji: {
    fontSize: 14,
  },
  subLabel: {
    color: 'rgba(255,255,255,0.9)',
    fontSize: 11,
  },
  subLabelActive: {
    color: 'black',
    fontWeight: '600',
  },
});
