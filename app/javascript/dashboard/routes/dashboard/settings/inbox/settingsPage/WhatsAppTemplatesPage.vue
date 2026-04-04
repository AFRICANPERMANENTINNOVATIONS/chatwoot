<script setup>
import { ref, reactive, onMounted, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { uploadFile } from 'dashboard/helper/uploadHelper';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  inbox: { type: Object, required: true },
});

const { t } = useI18n();
const store = useStore();

const templates = ref([]);
const isLoading = ref(false);
const isCreating = ref(false);
const isUploading = ref(false);
const showCreateForm = ref(false);
const fileInputRef = ref(null);

const form = reactive({
  name: '',
  language: 'en',
  category: 'UTILITY',
  headerType: 'NONE',
  headerText: '',
  headerMediaUrl: '',
  headerMediaFileName: '',
  bodyText: '',
  footerText: '',
});

const headerExamples = ref({});
const bodyExamples = ref({});

const categoryOptions = [
  { value: 'UTILITY', label: 'Utility' },
  { value: 'MARKETING', label: 'Marketing' },
  { value: 'AUTHENTICATION', label: 'Authentication' },
];

const headerTypeOptions = [
  { value: 'NONE', label: 'None' },
  { value: 'TEXT', label: 'Text' },
  { value: 'IMAGE', label: 'Image' },
  { value: 'VIDEO', label: 'Video' },
  { value: 'DOCUMENT', label: 'Document' },
];

const languageOptions = [
  { value: 'en', label: 'English' },
  { value: 'en_US', label: 'English (US)' },
  { value: 'fr', label: 'French' },
  { value: 'es', label: 'Spanish' },
  { value: 'pt_BR', label: 'Portuguese (BR)' },
  { value: 'de', label: 'German' },
  { value: 'it', label: 'Italian' },
  { value: 'ar', label: 'Arabic' },
  { value: 'hi', label: 'Hindi' },
  { value: 'zh_CN', label: 'Chinese (Simplified)' },
  { value: 'ja', label: 'Japanese' },
  { value: 'ko', label: 'Korean' },
  { value: 'tr', label: 'Turkish' },
  { value: 'ru', label: 'Russian' },
  { value: 'nl', label: 'Dutch' },
];

const MEDIA_ACCEPT = {
  IMAGE: 'image/jpeg,image/png',
  VIDEO: 'video/mp4',
  DOCUMENT: 'application/pdf',
};

const formatVariable = v => `{{${v}}}`;

const extractVariables = text => {
  const matches = text.match(/\{\{(\d+)\}\}/g);
  if (!matches) return [];
  return [...new Set(matches)].map(m => m.replace(/[{}]/g, ''));
};

const headerVariables = computed(() =>
  form.headerType === 'TEXT' ? extractVariables(form.headerText) : []
);
const bodyVariables = computed(() => extractVariables(form.bodyText));

const isTextHeader = computed(() => form.headerType === 'TEXT');
const isMediaHeader = computed(() =>
  ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(form.headerType)
);

const mediaAcceptHint = computed(() => {
  const hints = { IMAGE: 'JPEG, PNG', VIDEO: 'MP4', DOCUMENT: 'PDF' };
  return hints[form.headerType] || '';
});

const fileAccept = computed(() => MEDIA_ACCEPT[form.headerType] || '*/*');

watch(headerVariables, vars => {
  const updated = {};
  vars.forEach(v => {
    updated[v] = headerExamples.value[v] || '';
  });
  headerExamples.value = updated;
});

watch(bodyVariables, vars => {
  const updated = {};
  vars.forEach(v => {
    updated[v] = bodyExamples.value[v] || '';
  });
  bodyExamples.value = updated;
});

watch(
  () => form.headerType,
  () => {
    form.headerText = '';
    form.headerMediaUrl = '';
    form.headerMediaFileName = '';
    headerExamples.value = {};
  }
);

const allExamplesFilled = computed(() => {
  const headerFilled = headerVariables.value.every(v =>
    headerExamples.value[v]?.trim()
  );
  const bodyFilled = bodyVariables.value.every(v =>
    bodyExamples.value[v]?.trim()
  );
  return headerFilled && bodyFilled;
});

const hasVariables = computed(
  () => headerVariables.value.length > 0 || bodyVariables.value.length > 0
);

const isFormValid = computed(() => {
  const nameValid = form.name.match(/^[a-z0-9_]+$/);
  const bodyValid = form.bodyText.trim().length > 0;
  const examplesValid = !hasVariables.value || allExamplesFilled.value;
  const mediaValid = !isMediaHeader.value || form.headerMediaUrl.trim();
  return nameValid && bodyValid && examplesValid && mediaValid;
});

const statusConfig = {
  APPROVED: { icon: 'i-lucide-circle-check', color: 'text-n-teal-11' },
  PENDING: { icon: 'i-lucide-clock', color: 'text-n-amber-11' },
  REJECTED: { icon: 'i-lucide-circle-x', color: 'text-n-ruby-10' },
};

const getStatusDisplay = status => {
  const upper = status?.toUpperCase() || 'PENDING';
  const config = statusConfig[upper] || statusConfig.PENDING;
  const label = t(`INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.STATUS.${upper}`) || upper;
  return { ...config, label };
};

const fetchTemplates = async () => {
  isLoading.value = true;
  try {
    const result = await store.dispatch('inboxes/getWhatsAppTemplates', {
      inboxId: props.inbox.id,
    });
    templates.value = result.templates || [];
  } catch {
    useAlert(t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const handleFileUpload = async event => {
  const file = event.target.files?.[0];
  if (!file) return;

  isUploading.value = true;
  try {
    const { fileUrl } = await uploadFile(file);
    form.headerMediaUrl = fileUrl;
    form.headerMediaFileName = file.name;
    useAlert(t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.UPLOAD_SUCCESS'));
  } catch {
    useAlert(t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.UPLOAD_ERROR'));
  } finally {
    isUploading.value = false;
  }
};

const clearMediaFile = () => {
  form.headerMediaUrl = '';
  form.headerMediaFileName = '';
  if (fileInputRef.value) fileInputRef.value.value = '';
};

const buildComponents = () => {
  const components = [];

  if (isTextHeader.value && form.headerText.trim()) {
    const header = { type: 'HEADER', format: 'TEXT', text: form.headerText };
    if (headerVariables.value.length > 0) {
      header.example = {
        header_text: headerVariables.value.map(
          v => headerExamples.value[v] || ''
        ),
      };
    }
    components.push(header);
  } else if (isMediaHeader.value && form.headerMediaUrl.trim()) {
    components.push({
      type: 'HEADER',
      format: form.headerType,
      example: {
        media_url: form.headerMediaUrl,
      },
    });
  }

  const body = { type: 'BODY', text: form.bodyText };
  if (bodyVariables.value.length > 0) {
    body.example = {
      body_text: [bodyVariables.value.map(v => bodyExamples.value[v] || '')],
    };
  }
  components.push(body);

  if (form.footerText.trim()) {
    components.push({ type: 'FOOTER', text: form.footerText });
  }

  return components;
};

const resetForm = () => {
  form.name = '';
  form.language = 'en';
  form.category = 'UTILITY';
  form.headerType = 'NONE';
  form.headerText = '';
  form.headerMediaUrl = '';
  form.headerMediaFileName = '';
  form.bodyText = '';
  form.footerText = '';
  headerExamples.value = {};
  bodyExamples.value = {};
  if (fileInputRef.value) fileInputRef.value.value = '';
};

const handleCreate = async () => {
  if (!isFormValid.value) return;

  isCreating.value = true;
  try {
    await store.dispatch('inboxes/createWhatsAppTemplate', {
      inboxId: props.inbox.id,
      template: {
        name: form.name,
        language: form.language,
        category: form.category,
        components: buildComponents(),
      },
    });
    useAlert(t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.SUCCESS'));
    resetForm();
    showCreateForm.value = false;
    fetchTemplates();
  } catch {
    useAlert(t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.ERROR'));
  } finally {
    isCreating.value = false;
  }
};

const handleDelete = async templateName => {
  const confirmed = window.confirm(
    t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.DELETE.CONFIRM', {
      name: templateName,
    })
  );
  if (!confirmed) return;

  try {
    await store.dispatch('inboxes/deleteWhatsAppTemplate', {
      inboxId: props.inbox.id,
      templateName,
    });
    useAlert(t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.DELETE.SUCCESS'));
    fetchTemplates();
  } catch {
    useAlert(t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.DELETE.ERROR'));
  }
};

onMounted(fetchTemplates);
</script>

<template>
  <div class="flex flex-col gap-6 py-6">
    <!-- Page Header -->
    <div class="flex items-center justify-between">
      <div>
        <h3 class="text-lg font-medium text-n-slate-12">
          {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.SUBTITLE') }}
        </p>
      </div>
      <div class="flex gap-2">
        <NextButton
          variant="faded"
          color="slate"
          icon="i-lucide-refresh-cw"
          :is-loading="isLoading"
          @click="fetchTemplates"
        />
        <NextButton
          :label="t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.TITLE')"
          icon="i-lucide-plus"
          @click="showCreateForm = !showCreateForm"
        />
      </div>
    </div>

    <!-- Create Form -->
    <div
      v-if="showCreateForm"
      class="flex flex-col gap-4 p-4 rounded-lg border border-n-weak bg-n-alpha-black2"
    >
      <h4 class="text-sm font-medium text-n-slate-12">
        {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.TITLE') }}
      </h4>

      <Input
        v-model="form.name"
        :label="t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.NAME_LABEL')"
        :placeholder="
          t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.NAME_PLACEHOLDER')
        "
        :message="t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.NAME_HELP')"
        message-type="info"
      />

      <div class="grid grid-cols-2 gap-4">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.LANGUAGE_LABEL') }}
          </label>
          <ComboBox
            v-model="form.language"
            :options="languageOptions"
            class="[&>div>button]:bg-n-alpha-black2"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.CATEGORY_LABEL') }}
          </label>
          <ComboBox
            v-model="form.category"
            :options="categoryOptions"
            class="[&>div>button]:bg-n-alpha-black2"
          />
        </div>
      </div>

      <!-- Header Type -->
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.HEADER_TYPE_LABEL') }}
        </label>
        <ComboBox
          v-model="form.headerType"
          :options="headerTypeOptions"
          class="[&>div>button]:bg-n-alpha-black2"
        />
      </div>

      <!-- Text Header -->
      <div v-if="isTextHeader" class="flex flex-col gap-2">
        <Input
          v-model="form.headerText"
          :label="t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.HEADER_LABEL')"
          :placeholder="
            t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.HEADER_PLACEHOLDER')
          "
        />
        <div
          v-if="headerVariables.length > 0"
          class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-black2 border border-n-weak"
        >
          <p class="text-xs font-medium text-n-slate-11">
            {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.EXAMPLES_HEADER') }}
          </p>
          <div
            v-for="variable in headerVariables"
            :key="`header-${variable}`"
            class="flex items-center gap-2"
          >
            <span class="text-xs text-n-slate-10 w-12 shrink-0">
              {{ formatVariable(variable) }}
            </span>
            <Input
              :model-value="headerExamples[variable]"
              type="text"
              class="flex-1"
              :placeholder="
                t(
                  'INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.EXAMPLE_PLACEHOLDER',
                  { variable: `{{${variable}}}` }
                )
              "
              @update:model-value="val => (headerExamples[variable] = val)"
            />
          </div>
        </div>
      </div>

      <!-- Media Header -->
      <div
        v-if="isMediaHeader"
        class="flex flex-col gap-3 p-3 rounded-lg bg-n-alpha-black2 border border-n-weak"
      >
        <p class="text-xs font-medium text-n-slate-11">
          {{
            t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.MEDIA_HEADER_INFO', {
              format: mediaAcceptHint,
            })
          }}
        </p>

        <!-- File upload area -->
        <div v-if="!form.headerMediaUrl" class="flex flex-col gap-2">
          <label
            class="flex flex-col items-center justify-center gap-2 p-6 rounded-lg border-2 border-dashed cursor-pointer border-n-weak hover:border-n-slate-7 transition-colors"
          >
            <Icon icon="i-lucide-upload-cloud" class="size-8 text-n-slate-9" />
            <span class="text-sm text-n-slate-11">
              {{
                t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.UPLOAD_LABEL', {
                  format: mediaAcceptHint,
                })
              }}
            </span>
            <input
              ref="fileInputRef"
              type="file"
              :accept="fileAccept"
              class="hidden"
              :disabled="isUploading"
              @change="handleFileUpload"
            />
          </label>

          <div class="flex items-center gap-2">
            <div class="flex-1 h-px bg-n-weak" />
            <span class="text-xs text-n-slate-10">
              {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.OR_PASTE_URL') }}
            </span>
            <div class="flex-1 h-px bg-n-weak" />
          </div>

          <Input
            v-model="form.headerMediaUrl"
            type="url"
            :placeholder="
              t(
                'INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.MEDIA_URL_PLACEHOLDER'
              )
            "
          />
        </div>

        <!-- Uploaded file preview -->
        <div
          v-else
          class="flex items-center justify-between gap-2 p-3 rounded-lg bg-n-solid-2 border border-n-weak"
        >
          <div class="flex items-center gap-2 min-w-0">
            <Icon
              icon="i-lucide-file-check"
              class="size-5 text-n-teal-11 shrink-0"
            />
            <div class="min-w-0">
              <p class="text-sm font-medium text-n-slate-12 truncate">
                {{ form.headerMediaFileName || 'Media file' }}
              </p>
              <p class="text-xs text-n-slate-10 truncate">
                {{ form.headerMediaUrl }}
              </p>
            </div>
          </div>
          <NextButton
            variant="faded"
            color="slate"
            icon="i-lucide-x"
            size="sm"
            @click="clearMediaFile"
          />
        </div>

        <!-- Loading state -->
        <div
          v-if="isUploading"
          class="flex items-center gap-2 text-sm text-n-slate-11"
        >
          <Icon icon="i-lucide-loader-2" class="size-4 animate-spin" />
          {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.UPLOADING') }}
        </div>

        <p class="text-xs text-n-slate-10">
          {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.MEDIA_UPLOAD_HELP') }}
        </p>
      </div>

      <!-- Body -->
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BODY_LABEL') }}
        </label>
        <textarea
          v-model="form.bodyText"
          :placeholder="
            t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BODY_PLACEHOLDER')
          "
          rows="4"
          class="w-full px-3 py-2 text-sm rounded-lg border resize-none border-n-weak bg-n-alpha-black2 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:ring-2 focus:ring-n-brand"
        />
      </div>

      <!-- Body variable examples -->
      <div
        v-if="bodyVariables.length > 0"
        class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-black2 border border-n-weak"
      >
        <p class="text-xs font-medium text-n-slate-11">
          {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.EXAMPLES_BODY') }}
        </p>
        <div
          v-for="variable in bodyVariables"
          :key="`body-${variable}`"
          class="flex items-center gap-2"
        >
          <span class="text-xs text-n-slate-10 w-12 shrink-0">
            {{ formatVariable(variable) }}
          </span>
          <Input
            :model-value="bodyExamples[variable]"
            type="text"
            class="flex-1"
            :placeholder="
              t(
                'INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.EXAMPLE_PLACEHOLDER',
                { variable: `{{${variable}}}` }
              )
            "
            @update:model-value="val => (bodyExamples[variable] = val)"
          />
        </div>
        <p class="text-xs text-n-slate-10">
          {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.EXAMPLES_HELP') }}
        </p>
      </div>

      <!-- Footer -->
      <Input
        v-model="form.footerText"
        :label="t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.FOOTER_LABEL')"
        :placeholder="
          t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.FOOTER_PLACEHOLDER')
        "
      />

      <div class="flex gap-2 justify-end">
        <NextButton
          variant="faded"
          color="slate"
          label="Cancel"
          @click="
            showCreateForm = false;
            resetForm();
          "
        />
        <NextButton
          :label="t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.SUBMIT')"
          :disabled="!isFormValid || isCreating || isUploading"
          :is-loading="isCreating"
          @click="handleCreate"
        />
      </div>
    </div>

    <!-- Templates List -->
    <div v-if="isLoading" class="flex justify-center py-8">
      <span class="text-sm text-n-slate-11">{{
        t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.LIST.LOADING')
      }}</span>
    </div>

    <div v-else-if="templates.length === 0" class="py-8 text-center">
      <p class="text-sm text-n-slate-11">
        {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.LIST.EMPTY') }}
      </p>
    </div>

    <div v-else class="flex flex-col gap-2">
      <div
        v-for="template in templates"
        :key="template.id || template.name"
        class="flex items-center justify-between p-4 rounded-lg border border-n-weak bg-n-solid-2"
      >
        <div class="flex flex-col gap-1 flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <span class="text-sm font-medium text-n-slate-12 truncate">
              {{ template.name }}
            </span>
            <span
              class="flex items-center gap-1 text-xs"
              :class="getStatusDisplay(template.status).color"
            >
              <Icon
                :icon="getStatusDisplay(template.status).icon"
                class="size-3.5"
              />
              {{ getStatusDisplay(template.status).label }}
            </span>
          </div>
          <div class="flex items-center gap-3 text-xs text-n-slate-10">
            <span>{{ template.language }}</span>
            <span>{{ template.category }}</span>
            <span
              v-if="
                template.components?.find(
                  c =>
                    c.type === 'HEADER' &&
                    ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(c.format)
                )
              "
              class="flex items-center gap-1"
            >
              <Icon icon="i-lucide-paperclip" class="size-3" />
              {{ template.components.find(c => c.type === 'HEADER')?.format }}
            </span>
          </div>
          <p
            v-if="template.components?.find(c => c.type === 'BODY')?.text"
            class="mt-1 text-xs text-n-slate-11 truncate"
          >
            {{ template.components.find(c => c.type === 'BODY').text }}
          </p>
        </div>
        <NextButton
          variant="faded"
          color="ruby"
          icon="i-lucide-trash-2"
          size="sm"
          @click="handleDelete(template.name)"
        />
      </div>
    </div>
  </div>
</template>
