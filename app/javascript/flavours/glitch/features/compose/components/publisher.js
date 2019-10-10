//  Package imports.
import classNames from 'classnames';
import PropTypes from 'prop-types';
import React from 'react';
import { defineMessages, FormattedMessage, injectIntl } from 'react-intl';
import { length } from 'stringz';
import ImmutablePureComponent from 'react-immutable-pure-component';

//  Components.
import Button from 'flavours/glitch/components/button';
import Icon from 'flavours/glitch/components/icon';

//  Utils.
import { maxChars } from 'flavours/glitch/util/initial_state';

//  Messages.
const messages = defineMessages({
  publish: {
    defaultMessage: 'Toot',
    id: 'compose_form.publish',
  },
  publishLoud: {
    defaultMessage: '{publish}!',
    id: 'compose_form.publish_loud',
  },
  clear: {
    defaultMessage: 'Clear',
    id: 'compose_form.clear',
  },
});

export default @injectIntl
class Publisher extends ImmutablePureComponent {

  static propTypes = {
    countText: PropTypes.string,
    disabled: PropTypes.bool,
    intl: PropTypes.object.isRequired,
    onSecondarySubmit: PropTypes.func,
    onSubmit: PropTypes.func,
    onClearAll: PropTypes.func,
    privacy: PropTypes.oneOf(['direct', 'private', 'unlisted', 'local', 'public']),
    sideArm: PropTypes.oneOf(['none', 'direct', 'private', 'unlisted', 'local', 'public']),
  };

  render () {
    const { countText, disabled, intl, onSecondarySubmit, onSubmit, onClearAll, privacy, sideArm } = this.props;

    const diff = maxChars - length(countText || '');
    const computedClass = classNames('composer--publisher', {
      disabled: disabled || diff < 0,
      over: diff < 0,
    });

    return (
      <div className={computedClass}>
        <Button
          className='clear'
          onClick={onClearAll}
          title={intl.formatMessage(messages.clear)}
          text={
            <span>
              <Icon icon='trash-o' />
            </span>
          }
        />
        {sideArm && sideArm !== 'none' ? (
          <Button
            className='side_arm'
            disabled={disabled || diff < 0}
            onClick={onSecondarySubmit}
            style={{ padding: null }}
            text={
              <span>
                <Icon
                  icon={{
                    public: 'globe',
                    local: 'users',
                    unlisted: 'unlock',
                    private: 'lock',
                    direct: 'envelope',
                  }[sideArm]}
                />
              </span>
            }
            title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage({ id: `privacy.${sideArm}.short` })}`}
          />
        ) : null}
        <Button
          className='primary'
          text={function () {
            switch (true) {
            case !!sideArm && sideArm !== 'none':
            case privacy === 'direct':
            case privacy === 'private':
              return (
                <span>
                  <Icon
                    icon={{
                      direct: 'envelope',
                      private: 'lock',
                      public: 'globe',
                      unlisted: 'unlock',
                      local: 'users',
                    }[privacy]}
                  />
                  {' '}
                  <FormattedMessage {...messages.publish} />
                </span>
              );
            case privacy === 'public':
              return (
                <span>
                  <FormattedMessage
                    {...messages.publishLoud}
                    values={{ publish: <FormattedMessage {...messages.publish} /> }}
                  />
                </span>
              );
            default:
              return <span><FormattedMessage {...messages.publish} /></span>;
            }
          }()}
          title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage({ id: `privacy.${privacy}.short` })}`}
          onClick={onSubmit}
          disabled={disabled || diff < 0}
        />
      </div>
    );
  };
}
