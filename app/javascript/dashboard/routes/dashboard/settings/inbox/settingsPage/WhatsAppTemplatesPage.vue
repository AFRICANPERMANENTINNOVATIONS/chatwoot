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
  buttonType: 'NONE',
  buttons: [],
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

const buttonTypeOptions = [
  { value: 'NONE', label: 'None' },
  { value: 'QUICK_REPLY', label: 'Quick Reply' },
  { value: 'CTA', label: 'Call to Action' },
];

const ctaButtonSubtypeOptions = [
  { value: 'URL', label: 'URL' },
  { value: 'PHONE_NUMBER', label: 'Phone Number' },
];

const MAX_QUICK_REPLY = 10;
const MAX_URL_BUTTONS = 2;
const MAX_PHONE_BUTTONS = 1;

const addButton = () => {
  if (
    form.buttonType === 'QUICK_REPLY' &&
    form.buttons.length < MAX_QUICK_REPLY
  ) {
    form.buttons.push({ type: 'QUICK_REPLY', text: '' });
  } else if (form.buttonType === 'CTA' && form.buttons.length < 3) {
    form.buttons.push({
      type: 'URL',
      text: '',
      url: '',
      phone_number: '',
      urlExample: '',
    });
  }
};

const removeButton = index => {
  form.buttons.splice(index, 1);
};

const canAddButton = computed(() => {
  if (form.buttonType === 'QUICK_REPLY')
    return form.buttons.length < MAX_QUICK_REPLY;
  if (form.buttonType === 'CTA') {
    const urlCount = form.buttons.filter(b => b.type === 'URL').length;
    const phoneCount = form.buttons.filter(
      b => b.type === 'PHONE_NUMBER'
    ).length;
    return urlCount < MAX_URL_BUTTONS || phoneCount < MAX_PHONE_BUTTONS;
  }
  return false;
});

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

watch(
  () => form.buttonType,
  () => {
    form.buttons = [];
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

const buttonsValid = computed(() => {
  if (form.buttonType === 'NONE') return true;
  if (form.buttons.length === 0) return false;
  return form.buttons.every(btn => {
    if (!btn.text?.trim() && btn.type !== 'PHONE_NUMBER') return false;
    if (btn.type === 'QUICK_REPLY')
      return btn.text.trim().length > 0 && btn.text.length <= 25;
    if (btn.type === 'URL')
      return (
        btn.text.trim().length > 0 && btn.text.length <= 25 && btn.url?.trim()
      );
    if (btn.type === 'PHONE_NUMBER')
      return (
        btn.text.trim().length > 0 &&
        btn.text.length <= 25 &&
        btn.phone_number?.trim()
      );
    return true;
  });
});

const isFormValid = computed(() => {
  const nameValid = form.name.match(/^[a-z0-9_]+$/);
  const bodyValid = form.bodyText.trim().length > 0;
  const examplesValid = !hasVariables.value || allExamplesFilled.value;
  const mediaValid = !isMediaHeader.value || form.headerMediaUrl.trim();
  return (
    nameValid && bodyValid && examplesValid && mediaValid && buttonsValid.value
  );
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

  if (form.buttonType !== 'NONE' && form.buttons.length > 0) {
    const buttons = form.buttons.map(btn => {
      if (btn.type === 'QUICK_REPLY') {
        return { type: 'QUICK_REPLY', text: btn.text };
      }
      if (btn.type === 'URL') {
        const urlBtn = { type: 'URL', text: btn.text, url: btn.url };
        if (btn.url.includes('{{1}}') && btn.urlExample?.trim()) {
          urlBtn.example = [btn.urlExample];
        }
        return urlBtn;
      }
      if (btn.type === 'PHONE_NUMBER') {
        return {
          type: 'PHONE_NUMBER',
          text: btn.text,
          phone_number: btn.phone_number,
        };
      }
      return btn;
    });
    components.push({ type: 'BUTTONS', buttons });
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
  form.buttonType = 'NONE';
  form.buttons = [];
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

      <!-- Buttons -->
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.TYPE_LABEL') }}
        </label>
        <ComboBox
          v-model="form.buttonType"
          :options="buttonTypeOptions"
          class="[&>div>button]:bg-n-alpha-black2"
        />
      </div>

      <div
        v-if="form.buttonType !== 'NONE'"
        class="flex flex-col gap-3 p-3 rounded-lg bg-n-alpha-black2 border border-n-weak"
      >
        <p class="text-xs text-n-slate-11">
          {{
            form.buttonType === 'QUICK_REPLY'
              ? t(
                  'INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.QUICK_REPLY_HINT'
                )
              : t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.CTA_HINT')
          }}
        </p>

        <!-- Button list -->
        <div
          v-for="(btn, idx) in form.buttons"
          :key="`btn-${idx}`"
          class="flex flex-col gap-2 p-3 rounded-lg bg-n-solid-2 border border-n-weak"
        >
          <div class="flex items-center justify-between">
            <span class="text-xs font-medium text-n-slate-11">
              {{
                t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.BUTTON_N', {
                  n: idx + 1,
                })
              }}
            </span>
            <NextButton
              variant="faded"
              color="ruby"
              icon="i-lucide-x"
              size="xs"
              @click="removeButton(idx)"
            />
          </div>

          <!-- CTA subtype selector -->
          <div v-if="form.buttonType === 'CTA'" class="flex flex-col gap-1">
            <label class="text-xs text-n-slate-11">
              {{
                t(
                  'INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.SUBTYPE_LABEL'
                )
              }}
            </label>
            <ComboBox
              :model-value="btn.type"
              :options="ctaButtonSubtypeOptions"
              class="[&>div>button]:bg-n-alpha-black2"
              @update:model-value="
                val => {
                  btn.type = val;
                  btn.url = '';
                  btn.phone_number = '';
                  btn.urlExample = '';
                }
              "
            />
          </div>

          <Input
            v-model="btn.text"
            :label="
              t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.TEXT_LABEL')
            "
            :placeholder="
              t(
                'INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.TEXT_PLACEHOLDER'
              )
            "
            :message="
              btn.text.length > 25
                ? t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.TEXT_MAX')
                : ''
            "
            :message-type="btn.text.length > 25 ? 'error' : 'info'"
          />

          <!-- URL fields -->
          <template v-if="btn.type === 'URL'">
            <Input
              v-model="btn.url"
              :label="
                t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.URL_LABEL')
              "
              :placeholder="
                t(
                  'INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.URL_PLACEHOLDER'
                )
              "
              type="url"
            />
            <Input
              v-if="btn.url.includes('{' + '{1}}')"
              v-model="btn.urlExample"
              :label="
                t(
                  'INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.URL_EXAMPLE_LABEL'
                )
              "
              :placeholder="
                t(
                  'INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.URL_EXAMPLE_PLACEHOLDER'
                )
              "
              type="url"
            />
          </template>

          <!-- Phone fields -->
          <Input
            v-if="btn.type === 'PHONE_NUMBER'"
            v-model="btn.phone_number"
            :label="
              t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.PHONE_LABEL')
            "
            :placeholder="
              t(
                'INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.PHONE_PLACEHOLDER'
              )
            "
            type="tel"
          />
        </div>

        <!-- Add button -->
        <NextButton
          v-if="canAddButton"
          variant="faded"
          color="slate"
          icon="i-lucide-plus"
          :label="t('INBOX_MGMT.WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS.ADD')"
          size="sm"
          @click="addButton"
        />
      </div>

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
          <div
            v-if="template.components?.find(c => c.type === 'BUTTONS')"
            class="flex items-center gap-1.5 mt-1 flex-wrap"
          >
            <span
              v-for="(btn, bIdx) in template.components.find(
                c => c.type === 'BUTTONS'
              ).buttons"
              :key="`btn-${bIdx}`"
              class="px-2 py-0.5 text-xs rounded-full bg-n-alpha-3 text-n-slate-11"
            >
              <Icon
                :icon="
                  btn.type === 'URL'
                    ? 'i-lucide-external-link'
                    : btn.type === 'PHONE_NUMBER'
                      ? 'i-lucide-phone'
                      : 'i-lucide-reply'
                "
                class="size-3 inline-block mr-0.5 -mt-0.5"
              />
              {{ btn.text }}
            </span>
          </div>
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
