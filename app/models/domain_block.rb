# frozen_string_literal: true
# == Schema Information
#
# Table name: domain_blocks
#
#  id              :bigint(8)        not null, primary key
#  domain          :string           default(""), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  severity        :integer          default("noop")
#  reject_media    :boolean          default(FALSE), not null
#  reject_reports  :boolean          default(FALSE), not null
#  force_sensitive :boolean          default(FALSE), not null
#  reason          :text
#  reject_unknown  :boolean          default(FALSE), not null
#  processing      :boolean          default(TRUE), not null
#  manual_only     :boolean          default(FALSE), not null
#

class DomainBlock < ApplicationRecord
  include DomainNormalizable

  enum severity: [:noop, :force_unlisted, :silence, :suspend]

  validates :domain, presence: true, uniqueness: true

  has_many :accounts, foreign_key: :domain, primary_key: :domain
  delegate :count, to: :accounts, prefix: true

  scope :matches_domain, ->(value) { where(arel_table[:domain].matches("%#{value}%")) }
  scope :unprocessed, -> { where(processing: true) }
  scope :with_user_facing_limitations, -> { where(severity: [:silence, :suspend]).or(where(reject_media: true)).or(where(reject_unknown: true).or(where(manual_only: true))) }

  before_save :set_processing

  class << self
    def suspend?(domain)
      !!rule_for(domain)&.suspend?
    end

    def silence?(domain)
      !!rule_for(domain)&.silence?
    end

    def reject_media?(domain)
      !!rule_for(domain)&.reject_media?
    end

    def reject_reports?(domain)
      !!rule_for(domain)&.reject_reports?
    end

    def force_unlisted?(domain)
      !!rule_for(domain)&.severity == 'force_unlisted'
    end

    alias blocked? suspend?

    def rule_for(domain)
      return if domain.blank?

      uri      = Addressable::URI.new.tap { |u| u.host = domain.gsub(/[\/]/, '') }
      segments = uri.normalized_host.split('.')
      variants = segments.map.with_index { |_, i| segments[i..-1].join('.') }

      where(domain: variants[0..-2]).order(Arel.sql('char_length(domain) desc')).first
    end
  end

  def stricter_than?(other_block)
    return true if suspend?
    return false if other_block.suspend? && !suspend?
    return false if other_block.silence? && (noop? || force_unlisted?)
    return false if other_block.force_unlisted? && noop?
    (reject_media || !other_block.reject_media) && (reject_reports || !other_block.reject_reports)
  end

  def affected_accounts_count
    scope = suspend? ? accounts.where(suspended_at: created_at) : accounts.where(silenced_at: created_at)
    scope.count
  end

  def additionals
    additionals = []
    additionals << "force sensitive media" if force_sensitive?
    additionals << "reject media" if reject_media?
    additionals << "reject reports" if reject_reports?
    additionals << "reject unknown accounts" if reject_unknown?
    additionals << "manual trust only" if manual_only?
    additionals
  end

  def template
    self.attributes.except('id', 'domain', 'created_at', 'updated_at', 'processing')
  end

  # workaround for the domain policy editor
  def undo
    false
  end

  private

  def set_processing
    return if processing
    return unless (changed & %w(severity suspended_at silenced_at force_sensitive reject_media reject_reports reject_unknown manual_only)).any?

    self.processing = true
  end
end
