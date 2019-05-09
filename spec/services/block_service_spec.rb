require 'rails_helper'

RSpec.describe BlockService, type: :service do
  let(:sender) { Fabricate(:account, username: 'alice') }

  subject { BlockService.new }

  describe 'local' do
    let(:bob) { Fabricate(:user, email: 'bob@example.com', account: Fabricate(:account, username: 'bob')).account }

    before do
      subject.call(sender, bob)
    end

    it 'creates a blocking relation' do
      expect(sender.blocking?(bob)).to be true
    end
  end

  describe 'remote ActivityPub' do
    let(:bob) { Fabricate(:user, email: 'bob@example.com', account: Fabricate(:account, username: 'bob', domain: 'example.com', inbox_url: 'http://example.com/inbox')).account }

    before do
      stub_request(:post, 'http://example.com/inbox').to_return(status: 200)
      subject.call(sender, bob)
    end

    it 'creates a blocking relation' do
      expect(sender.blocking?(bob)).to be true
    end

    it 'sends a block activity' do
      expect(a_request(:post, 'http://example.com/inbox')).to have_been_made.once
    end
  end
end
