import { useMemo, useState } from 'react';
import { Platform, ScrollView, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';

/** Every row mounts — ScrollView, not FlatList (scroll / layout automation harness). */
export const LONG_LIST_ROW_COUNT = 1200;

/** Heavy synchronous CPU per row — runs on every scroll-driven full list re-render. */
function rowRenderOverhead(i: number) {
  let x = i + 1;
  for (let k = 0; k < 900; k += 1) {
    x = Math.sqrt(x * x + k + 1);
  }
  return x;
}

function StressRow({ i, scrollY }: { i: number; scrollY: number }) {
  rowRenderOverhead(i);
  const tag = (Math.floor(scrollY) + i * 31) % 997;
  return (
    <ThemedView style={[styles.row, Platform.OS === 'android' && styles.rowElevation]}>
      <ThemedText type="defaultSemiBold">
        List item {String(i).padStart(3, '0')} · {tag}
      </ThemedText>
    </ThemedView>
  );
}

export default function LongListScreen() {
  const insets = useSafeAreaInsets();
  const [scrollY, setScrollY] = useState(0);
  const [scrollEvents, setScrollEvents] = useState(0);
  const indices = useMemo(
    () => Array.from({ length: LONG_LIST_ROW_COUNT }, (_, i) => i),
    [],
  );

  return (
    <ThemedView style={[styles.container, { paddingTop: insets.top + 8 }]}>
      <ThemedView style={styles.banner}>
        <ThemedText type="subtitle">Unvirtualized list</ThemedText>
        <ThemedText style={styles.bannerDetail}>
          {LONG_LIST_ROW_COUNT.toLocaleString()} rows — scroll floods JS + re-renders every row each
          event ({scrollEvents} events). {scrollY.toFixed(0)}px
        </ThemedText>
      </ThemedView>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
        scrollEventThrottle={1}
        onScroll={(e) => {
          const y = e.nativeEvent.contentOffset.y;
          setScrollY(y);
          setScrollEvents((n) => n + 1);
        }}>
        {indices.map((i) => (
          <StressRow key={i} i={i} scrollY={scrollY} />
        ))}
      </ScrollView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  banner: {
    paddingHorizontal: 16,
    paddingBottom: 12,
    gap: 6,
  },
  bannerDetail: {
    opacity: 0.85,
    fontSize: 13,
    lineHeight: 18,
  },
  scroll: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 24,
  },
  row: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(128,128,128,0.35)',
  },
  /** Per-row shadows → expensive native updates on large hierarchies (Android). */
  rowElevation: {
    elevation: 10,
  },
});
