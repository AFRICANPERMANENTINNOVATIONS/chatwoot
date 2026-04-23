<script setup>
import { computed, onMounted } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store.js';

import BillingMeter from '../billing/components/BillingMeter.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const store = useStore();
const plan = useMapGetter('plan/getPlan');
const uiFlags = useMapGetter('plan/getUIFlags');

const planName = computed(() => plan.value?.plan_name || null);
const displayName = computed(
  () => plan.value?.display_name || plan.value?.plan_name || null
);
const limits = computed(() => plan.value?.limits || {});
const features = computed(() => plan.value?.features || []);

const meters = computed(() => {
  const l = limits.value;
  return [
    { key: 'agents', title: 'PLAN_SETTINGS.LIMITS.AGENTS', data: l.agents },
    { key: 'inboxes', title: 'PLAN_SETTINGS.LIMITS.INBOXES', data: l.inboxes },
    {
      key: 'captain_responses',
      title: 'PLAN_SETTINGS.LIMITS.CAPTAIN_RESPONSES',
      data: l.captain_responses,
    },
    {
      key: 'captain_documents',
      title: 'PLAN_SETTINGS.LIMITS.CAPTAIN_DOCUMENTS',
      data: l.captain_documents,
    },
  ].filter(m => m.data && Number(m.data.allowed) > 0);
});

onMounted(() => {
  store.dispatch('plan/fetch');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('PLAN_SETTINGS.LOADING')"
    :no-records-found="!planName && !uiFlags.isFetching"
    :no-records-message="$t('PLAN_SETTINGS.NO_PLAN')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('PLAN_SETTINGS.TITLE')"
        :description="$t('PLAN_SETTINGS.DESCRIPTION')"
        :show-back-button="false"
      />
    </template>
    <template #body>
      <section class="grid gap-6">
        <div class="rounded-xl border border-n-weak bg-n-background p-6">
          <div class="text-xs uppercase tracking-wider text-n-slate-10">
            {{ $t('PLAN_SETTINGS.CURRENT_PLAN') }}
          </div>
          <div class="text-2xl font-semibold text-n-slate-12 mt-1">
            {{ displayName }}
          </div>
        </div>

        <div
          v-if="meters.length"
          class="rounded-xl border border-n-weak bg-n-background p-6 grid gap-5"
        >
          <div class="text-sm font-medium text-n-slate-12">
            {{ $t('PLAN_SETTINGS.USAGE') }}
          </div>
          <div v-for="meter in meters" :key="meter.key" class="grid gap-1">
            <BillingMeter
              :title="$t(meter.title)"
              :consumed="Number(meter.data.consumed) || 0"
              :total-count="Number(meter.data.allowed) || 0"
            />
          </div>
        </div>

        <div
          v-if="features.length"
          class="rounded-xl border border-n-weak bg-n-background p-6"
        >
          <div class="text-sm font-medium text-n-slate-12 mb-4">
            {{ $t('PLAN_SETTINGS.FEATURES') }}
          </div>
          <div
            class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-x-6 gap-y-2"
          >
            <div
              v-for="feature in features"
              :key="feature"
              class="flex items-center gap-2 text-sm text-n-slate-11"
            >
              <span class="i-lucide-check text-n-teal-10" />
              <span>{{ feature }}</span>
            </div>
          </div>
        </div>
      </section>
    </template>
  </SettingsLayout>
</template>
