/* global axios */
import CacheEnabledApiClient from './CacheEnabledApiClient';

class Inboxes extends CacheEnabledApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'inbox';
  }

  getCampaigns(inboxId) {
    return axios.get(`${this.url}/${inboxId}/campaigns`);
  }

  deleteInboxAvatar(inboxId) {
    return axios.delete(`${this.url}/${inboxId}/avatar`);
  }

  getAgentBot(inboxId) {
    return axios.get(`${this.url}/${inboxId}/agent_bot`);
  }

  setAgentBot(inboxId, botId) {
    return axios.post(`${this.url}/${inboxId}/set_agent_bot`, {
      agent_bot: botId,
    });
  }

  syncTemplates(inboxId) {
    return axios.post(`${this.url}/${inboxId}/sync_templates`);
  }

  createCSATTemplate(inboxId, template) {
    return axios.post(`${this.url}/${inboxId}/csat_template`, {
      template,
    });
  }

  getCSATTemplateStatus(inboxId) {
    return axios.get(`${this.url}/${inboxId}/csat_template`);
  }

  analyzeCSATTemplateUtility(inboxId, template) {
    return axios.post(`${this.url}/${inboxId}/csat_template/analyze`, {
      template,
    });
  }

  getWhatsAppTemplates(inboxId) {
    return axios.get(`${this.url}/${inboxId}/whatsapp_templates`);
  }

  createWhatsAppTemplate(inboxId, template) {
    return axios.post(`${this.url}/${inboxId}/whatsapp_templates`, {
      template,
    });
  }

  deleteWhatsAppTemplate(inboxId, templateName) {
    return axios.delete(
      `${this.url}/${inboxId}/whatsapp_templates/${templateName}`
    );
  }

  getWhatsAppTemplateStatus(inboxId, templateName) {
    return axios.get(
      `${this.url}/${inboxId}/whatsapp_templates/${templateName}`
    );
  }
}

export default new Inboxes();
