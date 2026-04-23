<script setup>
import { reactive, computed, watch, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, minValue } from '@vuelidate/validators';
import { debounce } from '@chatwoot/utils';
import { useMapGetter } from 'dashboard/composables/store';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import filterQueryGenerator from 'dashboard/helper/filterQueryGenerator';
import CampaignsAPI from 'dashboard/api/campaigns';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import ConditionRow from 'dashboard/components-next/filter/ConditionRow.vue';
import { useContactFilterContext } from 'dashboard/components-next/filter/contactProvider.js';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const { filterTypes } = useContactFilterContext();

const DEFAULT_DAILY_SOFT_LIMIT = 10000;

const DEFAULT_CONDITION = {
  attributeKey: 'name',
  filterOperator: 'equal_to',
  values: '',
  queryOperator: 'and',
  attributeModel: 'standard',
};

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  inboxes: useMapGetter('inboxes/getWhatsAppInboxes'),
  getFilteredWhatsAppTemplates: useMapGetter(
    'inboxes/getFilteredWhatsAppTemplates'
  ),
};

const initialState = {
  title: '',
  inboxId: null,
  templateId: null,
  scheduledAt: null,
  batchSize: null,
  batchIntervalMinutes: null,
  audienceCap: DEFAULT_DAILY_SOFT_LIMIT,
};

const state = reactive({ ...initialState });
const audienceFilters = ref([{ ...DEFAULT_CONDITION }]);
const audienceCount = ref(null);
const audiencePreviewLoading = ref(false);
const templateParserRef = ref(null);

const hasAudienceValues = computed(() =>
  audienceFilters.value.some(condition => {
    const value = condition.values;
    if (Array.isArray(value)) return value.length > 0;
    return value !== '' && value !== null && value !== undefined;
  })
);

const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  templateId: { required },
  scheduledAt: { required },
  audienceCount: { required, minValue: minValue(1) },
};

const v$ = useVuelidate(rules, {
  title: computed(() => state.title),
  inboxId: computed(() => state.inboxId),
  templateId: computed(() => state.templateId),
  scheduledAt: computed(() => state.scheduledAt),
  audienceCount: audienceCount,
});

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

const templateOptions = computed(() => {
  if (!state.inboxId) return [];
  const templates = formState.getFilteredWhatsAppTemplates.value(state.inboxId);
  return templates.map(template => {
    const friendlyName = template.name
      .replace(/_/g, ' ')
      .replace(/\b\w/g, l => l.toUpperCase());
    return {
      value: template.id,
      label: `${friendlyName} (${template.language || 'en'})`,
      template: template,
    };
  });
});

const selectedTemplate = computed(() => {
  if (!state.templateId) return null;
  return templateOptions.value.find(option => option.value === state.templateId)
    ?.template;
});

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.WHATSAPP.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  template: getErrorMessage('templateId', 'TEMPLATE'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
}));

const hasRequiredTemplateParams = computed(() => {
  return templateParserRef.value?.v$?.$invalid === false || true;
});

const isSubmitDisabled = computed(
  () => v$.value.$invalid || !hasRequiredTemplateParams.value
);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const buildAudiencePayload = () => {
  if (!hasAudienceValues.value) return null;
  const snake = useSnakeCase(JSON.parse(JSON.stringify(audienceFilters.value)));
  const { payload } = filterQueryGenerator(snake);
  return [{ type: 'Filter', query: payload }];
};

const fetchAudienceCount = debounce(async () => {
  const audience = buildAudiencePayload();
  if (!audience) {
    audienceCount.value = null;
    return;
  }
  audiencePreviewLoading.value = true;
  try {
    const { data } = await CampaignsAPI.audiencePreview(audience);
    audienceCount.value = data.count;
  } catch {
    audienceCount.value = null;
  } finally {
    audiencePreviewLoading.value = false;
  }
}, 500);

watch(audienceFilters, fetchAudienceCount, { deep: true });

const addCondition = () => {
  audienceFilters.value.push({ ...DEFAULT_CONDITION });
};

const removeCondition = index => {
  if (audienceFilters.value.length === 1) {
    audienceFilters.value = [{ ...DEFAULT_CONDITION }];
  } else {
    audienceFilters.value.splice(index, 1);
  }
};

const resetState = () => {
  Object.assign(state, initialState);
  audienceFilters.value = [{ ...DEFAULT_CONDITION }];
  audienceCount.value = null;
  v$.value.$reset();
};

const handleCancel = () => emit('cancel');

const prepareCampaignDetails = () => {
  const currentTemplate = selectedTemplate.value;
  const parserData = templateParserRef.value;
  const templateContent = parserData?.renderedTemplate || '';
  const templateParams = {
    name: currentTemplate?.name || '',
    namespace: currentTemplate?.namespace || '',
    category: currentTemplate?.category || 'UTILITY',
    language: currentTemplate?.language || 'en_US',
    processed_params: parserData?.processedParams || {},
  };

  const batchSize = Number(state.batchSize) || 0;
  const batchIntervalMinutes = Number(state.batchIntervalMinutes) || 0;
  const triggerRules =
    batchSize > 0
      ? {
          batch_size: batchSize,
          batch_interval_minutes: batchIntervalMinutes,
        }
      : {};

  return {
    title: state.title,
    message: templateContent,
    template_params: templateParams,
    inbox_id: state.inboxId,
    scheduled_at: formatToUTCString(state.scheduledAt),
    audience: buildAudiencePayload() || [],
    trigger_rules: triggerRules,
  };
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};

watch(
  () => state.inboxId,
  () => {
    state.templateId = null;
  }
);
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label for="template" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.LABEL') }}
      </label>
      <ComboBox
        id="template"
        v-model="state.templateId"
        :options="templateOptions"
        :has-error="!!formErrors.template"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.PLACEHOLDER')"
        :message="formErrors.template"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.INFO') }}
      </p>
    </div>

    <WhatsAppTemplateParser
      v-if="selectedTemplate"
      ref="templateParserRef"
      :template="selectedTemplate"
    />

    <div
      v-if="selectedTemplate"
      class="p-3 rounded-lg border border-n-weak bg-n-alpha-black2"
    >
      <p class="mb-1 text-xs font-medium text-n-slate-11">
        {{ t('WHATSAPP_TEMPLATES.PARSER.CONTACT_VARIABLES_HINT') }}
      </p>
      <p class="text-xs break-all text-n-slate-10">
        {{ t('WHATSAPP_TEMPLATES.PARSER.CONTACT_VARIABLES_EXAMPLES') }}
      </p>
    </div>

    <div class="flex flex-col gap-2">
      <div class="flex items-center justify-between">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL') }}
        </label>
        <div class="flex items-center gap-2 text-xs">
          <span v-if="audiencePreviewLoading" class="text-n-slate-10">
            {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.PREVIEW_LOADING') }}
          </span>
          <span
            v-else-if="audienceCount !== null"
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full font-medium"
            :class="
              audienceCount === 0
                ? 'bg-n-ruby-2 text-n-ruby-11'
                : 'bg-n-teal-2 text-n-teal-11'
            "
          >
            {{
              t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.COUNT', {
                n: audienceCount,
              })
            }}
          </span>
        </div>
      </div>
      <p class="text-xs text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.HINT') }}
      </p>
      <ul class="grid gap-3 list-none p-0 m-0">
        <template v-for="(filter, index) in audienceFilters" :key="index">
          <ConditionRow
            v-if="index === 0"
            v-model:attribute-key="filter.attributeKey"
            v-model:filter-operator="filter.filterOperator"
            v-model:values="filter.values"
            :filter-types="filterTypes"
            :show-query-operator="false"
            @remove="removeCondition(index)"
          />
          <ConditionRow
            v-else
            v-model:attribute-key="filter.attributeKey"
            v-model:filter-operator="filter.filterOperator"
            v-model:query-operator="audienceFilters[index - 1].queryOperator"
            v-model:values="filter.values"
            :filter-types="filterTypes"
            show-query-operator
            @remove="removeCondition(index)"
          />
        </template>
      </ul>
      <div class="flex">
        <Button sm ghost blue type="button" @click="addCondition">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.ADD_CONDITION') }}
        </Button>
      </div>
      <div class="grid grid-cols-[1fr_auto] gap-3 items-end">
        <Input
          v-model="state.audienceCap"
          type="number"
          min="0"
          :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.CAP.LABEL')"
          :placeholder="
            t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.CAP.PLACEHOLDER')
          "
        />
        <p class="pb-2 text-xs text-n-slate-11">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.CAP.HINT') }}
        </p>
      </div>
      <p
        v-if="
          audienceCount !== null &&
          Number(state.audienceCap) > 0 &&
          audienceCount > Number(state.audienceCap)
        "
        class="flex items-center gap-2 px-3 py-2 rounded-md text-xs font-medium bg-n-amber-2 text-n-amber-11"
      >
        {{
          t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.OVER_LIMIT_WARNING', {
            limit: Number(state.audienceCap),
          })
        }}
      </p>
    </div>

    <Input
      v-model="state.scheduledAt"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.LABEL')"
      type="datetime-local"
      :min="currentDateTime"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <div class="p-3 rounded-lg border border-n-weak bg-n-alpha-black2">
      <p class="mb-2 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.BATCH.TITLE') }}
      </p>
      <p class="mb-3 text-xs text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.BATCH.HINT') }}
      </p>
      <div class="grid grid-cols-2 gap-3">
        <Input
          v-model="state.batchSize"
          type="number"
          min="0"
          :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BATCH.SIZE.LABEL')"
          :placeholder="
            t('CAMPAIGN.WHATSAPP.CREATE.FORM.BATCH.SIZE.PLACEHOLDER')
          "
        />
        <Input
          v-model="state.batchIntervalMinutes"
          type="number"
          min="0"
          :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BATCH.INTERVAL.LABEL')"
          :placeholder="
            t('CAMPAIGN.WHATSAPP.CREATE.FORM.BATCH.INTERVAL.PLACEHOLDER')
          "
        />
      </div>
    </div>

    <div class="flex gap-3 justify-between items-center w-full">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
