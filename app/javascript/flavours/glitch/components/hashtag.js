import React from 'react';
import { FormattedMessage } from 'react-intl';
import ImmutablePropTypes from 'react-immutable-proptypes';
import Permalink from './permalink';
import { shortNumberFormat } from 'flavours/glitch/util/numbers';

const Hashtag = ({ hashtag }) => (
  <Permalink className='hashtag' href={hashtag.get('url')} to={`/timelines/tag/${hashtag.get('name')}`}>
    #<span>{hashtag.get('name')}</span>
  </Permalink>
);

Hashtag.propTypes = {
  hashtag: ImmutablePropTypes.map.isRequired,
};

export default Hashtag;
