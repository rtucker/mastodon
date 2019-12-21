import Immutable from 'immutable';

import {
  MUTES_INIT_MODAL,
  MUTES_TOGGLE_HIDE_NOTIFICATIONS,
  MUTES_TOGGLE_TIMELINES_ONLY,
} from 'flavours/glitch/actions/mutes';

const initialState = Immutable.Map({
  new: Immutable.Map({
    isSubmitting: false,
    account: null,
    notifications: true,
    timelinesOnly: false,
  }),
});

export default function mutes(state = initialState, action) {
  switch (action.type) {
  case MUTES_INIT_MODAL:
    return state.withMutations((state) => {
      state.setIn(['new', 'isSubmitting'], false);
      state.setIn(['new', 'account'], action.account);
      state.setIn(['new', 'notifications'], true);
      state.setIn(['new', 'timelinesOnly'], false);
    });
  case MUTES_TOGGLE_HIDE_NOTIFICATIONS:
    return state.updateIn(['new', 'notifications'], (old) => !old);
  case MUTES_TOGGLE_TIMELINES_ONLY:
    return state.updateIn(['new', 'timelines_only'], (old) => !old);
  default:
    return state;
  }
}
