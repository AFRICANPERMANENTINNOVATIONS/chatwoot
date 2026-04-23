import ApiClient from './ApiClient';

class PlanAPI extends ApiClient {
  constructor() {
    super('plan', { accountScoped: true });
  }
}

export default new PlanAPI();
