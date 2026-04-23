import types from '../mutation-types';
import PlanAPI from '../../api/plan';

export const state = {
  record: {
    plan_name: null,
    display_name: null,
    limits: {},
    features: [],
  },
  uiFlags: {
    isFetching: false,
  },
};

export const getters = {
  getPlan(_state) {
    return _state.record;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  fetch: async ({ commit }) => {
    commit(types.SET_PLAN_UI_FLAG, { isFetching: true });
    try {
      const response = await PlanAPI.get();
      commit(types.SET_PLAN, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_PLAN_UI_FLAG, { isFetching: false });
    }
  },
};

export const mutations = {
  [types.SET_PLAN_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.SET_PLAN](_state, data) {
    _state.record = data;
  },
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
