/* global axios */
import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  audiencePreview(audience) {
    return axios.post(`${this.url}/audience_preview`, { audience });
  }
}

export default new CampaignsAPI();
