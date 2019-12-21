import React from 'react';
import { connect } from 'react-redux';
import PropTypes from 'prop-types';
import { injectIntl, FormattedMessage } from 'react-intl';
import Toggle from 'react-toggle';
import Button from 'flavours/glitch/components/button';
import { closeModal } from 'flavours/glitch/actions/modal';
import { muteAccount } from 'flavours/glitch/actions/accounts';
import { toggleHideNotifications } from 'flavours/glitch/actions/mutes';
import { toggleTimelinesOnly } from 'flavours/glitch/actions/mutes';


const mapStateToProps = state => {
  return {
    isSubmitting: state.getIn(['reports', 'new', 'isSubmitting']),
    account: state.getIn(['mutes', 'new', 'account']),
    notifications: state.getIn(['mutes', 'new', 'notifications']),
    timelinesOnly: state.getIn(['mutes', 'new', 'timelines_only']),
  };
};

const mapDispatchToProps = dispatch => {
  return {
    onConfirm(account, notifications, timelinesOnly) {
      dispatch(muteAccount(account.get('id'), notifications, timelinesOnly));
    },

    onClose() {
      dispatch(closeModal());
    },

    onToggleNotifications() {
      dispatch(toggleHideNotifications());
    },

    onToggleTimelinesOnly() {
      dispatch(toggleTimelinesOnly());
    },
  };
};

@connect(mapStateToProps, mapDispatchToProps)
@injectIntl
export default class MuteModal extends React.PureComponent {

  static propTypes = {
    isSubmitting: PropTypes.bool.isRequired,
    account: PropTypes.object.isRequired,
    notifications: PropTypes.bool.isRequired,
    timelinesOnly: PropTypes.bool.isRequired,
    onClose: PropTypes.func.isRequired,
    onConfirm: PropTypes.func.isRequired,
    onToggleNotifications: PropTypes.func.isRequired,
    onTimelinesOnly: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  componentDidMount() {
    this.button.focus();
  }

  handleClick = () => {
    this.props.onClose();
    this.props.onConfirm(this.props.account, this.props.notifications, this.props.timelinesOnly);
  }

  handleCancel = () => {
    this.props.onClose();
  }

  setRef = (c) => {
    this.button = c;
  }

  toggleNotifications = () => {
    this.props.onToggleNotifications();
  }

  toggleTimelinesOnly = () => {
    this.props.onToggleTimelinesOnly();
  }

  render () {
    const { account, notifications, timelinesOnly } = this.props;

    return (
      <div className='modal-root__modal mute-modal'>
        <div className='mute-modal__container'>
          <p>
            <FormattedMessage
              id='confirmations.mute.message'
              defaultMessage='Are you sure you want to mute {name}?'
              values={{ name: <strong>@{account.get('acct')}</strong> }}
            />
          </p>
          <div>
            <label htmlFor='mute-modal__hide-notifications-checkbox'>
              <FormattedMessage id='mute_modal.hide_notifications' defaultMessage='Hide notifications from this user?' />
              {' '}
              <Toggle id='mute-modal__hide-notifications-checkbox' checked={notifications} onChange={this.toggleNotifications} />
            </label>
          </div>
          <div>
            <label htmlFor='mute-modal__timelines-only-checkbox'>
              <FormattedMessage id='mute_modal.timelines_only' defaultMessage='Hide from timelines only?' />
              {' '}
              <Toggle id='mute-modal__timelines-only-checkbox' checked={timelinesOnly} onChange={this.toggleTimelinesOnly} />
            </label>
          </div>
        </div>

        <div className='mute-modal__action-bar'>
          <Button onClick={this.handleCancel} className='mute-modal__cancel-button'>
            <FormattedMessage id='confirmation_modal.cancel' defaultMessage='Cancel' />
          </Button>
          <Button onClick={this.handleClick} ref={this.setRef}>
            <FormattedMessage id='confirmations.mute.confirm' defaultMessage='Mute' />
          </Button>
        </div>
      </div>
    );
  }

}
