<script setup lang="ts">
import { useOverviewInfo } from "@/hooks/useOverviewInfo";
import { getRandomId } from "@/tools/randId";
import type { LayoutCard } from "@/types";
import { watch } from "vue";
import { useOverviewChart } from "../hooks/useOverviewChart";
import type { JsonData } from "../types/index";

defineProps<{
  card: LayoutCard;
}>();

const domId = getRandomId();
const { state } = useOverviewInfo();

const chart = useOverviewChart(domId);

watch(state, () => {
  const source = state.value?.chart.request;
  if (!source || !chart) return;
  const MAX_TIME = source.length - 1;
  for (const key in source) {
    const v = source[key] as JsonData;
    v.time = `${MAX_TIME - Number(key) * 1}s`;
  }
  const maxRunning = Math.max(...source.map((v) => Number((v as JsonData).runningInstance ?? 0)));
  chart.setOption({
    yAxis: {
      max: maxRunning <= 1 ? 1 : maxRunning
    },
    dataset: {
      dimensions: ["time", "runningInstance"],
      source
    }
  });
});
</script>

<template>
  <CardPanel class="CardWrapper" style="height: 100%">
    <template #title>{{ card.title }}</template>
    <template #body>
      <div :id="domId" :style="{ width: '100%', height: '100%' }"></div>
    </template>
  </CardPanel>
</template>

<style lang="scss" scoped></style>
