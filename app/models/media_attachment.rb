# frozen_string_literal: true
# == Schema Information
#
# Table name: media_attachments
#
#  id                  :bigint(8)        not null, primary key
#  status_id           :bigint(8)
#  file_file_name      :string
#  file_content_type   :string
#  file_file_size      :integer
#  file_updated_at     :datetime
#  remote_url          :string           default(""), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  shortcode           :string
#  type                :integer          default("image"), not null
#  file_meta           :json
#  account_id          :bigint(8)
#  description         :text
#  scheduled_status_id :bigint(8)
#  blurhash            :string
#

class MediaAttachment < ApplicationRecord
  self.inheritance_column = nil

  enum type: [:image, :gifv, :video, :audio, :unknown]

  IMAGE_FILE_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].freeze
  VIDEO_FILE_EXTENSIONS = ['.webm', '.mp4', '.m4v', '.mov'].freeze
  AUDIO_FILE_EXTENSIONS = ['.mp3', '.m4a', '.wav', '.ogg', '.aac'].freeze

  IMAGE_MIME_TYPES             = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'].freeze
  VIDEO_MIME_TYPES             = ['video/ogg', 'video/webm', 'video/mp4', 'video/quicktime'].freeze
  VIDEO_CONVERTIBLE_MIME_TYPES = ['video/quicktime'].freeze
  AUDIO_MIME_TYPES             = ['audio/mp3', 'audio/x-mp3', 'audio/mpeg', 'audio/x-mpeg', 'audio/mp4', 'audio/vnd.wav', 'audio/wav', 'audio/x-wav', 'audio/x-wave', 'audio/ogg', 'audio/aac', 'audio/flac'].freeze
  AUDIO_CONVERTIBLE_MIME_TYPES = ['audio/vnd.wav', 'audio/wav', 'audio/x-wav', 'audio/x-wave', 'audio/ogg', 'audio/flac'].freeze

  BLURHASH_OPTIONS = {
    x_comp: 4,
    y_comp: 4,
  }.freeze

  IMAGE_STYLES = {
    original: {
      pixels: 16777216, # 4096x4096px
      file_geometry_parser: FastGeometryParser,
    },

    small: {
      pixels: 160_000, # 400x400px
      file_geometry_parser: FastGeometryParser,
      blurhash: BLURHASH_OPTIONS,
    },
  }.freeze

  GIF_THUMB_FORMAT = {
    format: 'png',
    pixels: 160_000, # 400x400px
    file_geometry_parser: FastGeometryParser,
  }.freeze

  AUDIO_STYLES = {
    small: {
      format: 'png',
      time: 0,
      convert_options: {
        output: {
          filter_complex: '"showwavespic=s=400x100:colors=lime|green"',
        },
      },
    },

    thumb: {
      format: 'png',
      time: 0,
      convert_options: {
        output: {
          filter_complex: '"showwavespic=s=400x100:colors=lime|green"',
        },
      },
    },
  }.freeze

  AUDIO_FORMAT = {
    format: 'm4a',
    convert_options: {
      output: {
        vn: '',
        acodec: 'aac',
        movflags: '+faststart',
      },
    },
  }.freeze

  VIDEO_STYLES = {
    small: {
      convert_options: {
        output: {
          vf: 'scale=\'min(400\, iw):min(400\, ih)\':force_original_aspect_ratio=decrease',
        },
      },
      format: 'png',
      time: 0,
      file_geometry_parser: FastGeometryParser,
      blurhash: BLURHASH_OPTIONS,
    },
  }.freeze

  VIDEO_FORMAT = {
    format: 'mp4',
    convert_options: {
      output: {
        'loglevel' => 'fatal',
        'movflags' => 'faststart',
        'pix_fmt'  => 'yuv420p',
        'vf'       => 'scale=\'trunc(iw/2)*2:trunc(ih/2)*2\'',
        'vsync'    => 'cfr',
        'c:v'      => 'h264',
        'b:v'      => '500K',
        'maxrate'  => '1300K',
        'bufsize'  => '1300K',
        'crf'      => 18,
      },
    },
  }.freeze

  SIZE_LIMIT = 66.megabytes
  GIF_LIMIT = ENV.fetch('MAX_GIF_SIZE', 333).to_i.kilobytes

  belongs_to :account,          inverse_of: :media_attachments, optional: true
  belongs_to :status,           inverse_of: :media_attachments, optional: true
  belongs_to :scheduled_status, inverse_of: :media_attachments, optional: true

  has_attached_file :file,
                    styles: ->(f) { file_styles f },
                    processors: ->(f) { file_processors f },
                    convert_options: { all: '-quality 90 -strip' }

  do_not_validate_attachment_file_type :file
  validates_attachment_size :file, less_than: SIZE_LIMIT
  remotable_attachment :file, SIZE_LIMIT

  include Attachmentable

  validates :account, presence: true
  validates :description, length: { maximum: 666 }, if: :local?

  scope :attached,   -> { where.not(status_id: nil).or(where.not(scheduled_status_id: nil)) }
  scope :unattached, -> { where(status_id: nil, scheduled_status_id: nil) }
  scope :local,      -> { where(remote_url: '') }
  scope :remote,     -> { where.not(remote_url: '') }

  default_scope { order(id: :asc) }

  def local?
    remote_url.blank?
  end

  def needs_redownload?
    file.blank? && remote_url.present?
  end

  def video_or_audio?
    video? || gifv? || audio?
  end

  def is_media?
    file_content_type.in?(IMAGE_MIME_TYPES + VIDEO_MIME_TYPES + AUDIO_MIME_TYPES)
  end

  def to_param
    shortcode
  end

  def focus=(point)
    return if point.blank?

    x, y = (point.is_a?(Enumerable) ? point : point.split(',')).map(&:to_f)

    meta = file.instance_read(:meta) || {}
    meta['focus'] = { 'x' => x, 'y' => y }

    file.instance_write(:meta, meta)
  end

  def focus
    x = file.meta['focus']['x']
    y = file.meta['focus']['y']

    "#{x},#{y}"
  end

  after_commit :reset_parent_cache, on: :update
  before_create :prepare_description, unless: :local?
  before_create :set_shortcode
  before_create :set_file_name, unless: :is_media?
  before_post_process :set_type_and_extension
  before_post_process :is_media?
  before_save :set_meta

  class << self
    private

    def file_styles(f)
      if f.instance.file_content_type == 'image/gif'
        if f.instance.file_file_size > GIF_LIMIT
          {
            small: IMAGE_STYLES[:small],
            original: VIDEO_FORMAT,
          }
        else
          {
            small: GIF_THUMB_FORMAT,
            original: IMAGE_STYLES[:original],
          }
        end
      elsif IMAGE_MIME_TYPES.include? f.instance.file_content_type
        IMAGE_STYLES
      elsif AUDIO_CONVERTIBLE_MIME_TYPES.include?(f.instance.file_content_type)
        {
          small: AUDIO_STYLES[:small],
          original: AUDIO_FORMAT,
        }
      elsif AUDIO_MIME_TYPES.include? f.instance.file_content_type
        AUDIO_STYLES
      elsif VIDEO_CONVERTIBLE_MIME_TYPES.include?(f.instance.file_content_type)
        {
          small: VIDEO_STYLES[:small],
          original: VIDEO_FORMAT,
        }
      elsif VIDEO_MIME_TYPES.include? f.instance.file_content_type
        VIDEO_STYLES
      else
        {original: {}}
      end
    end

    def file_processors(f)
      if f.file_content_type == 'image/gif'
        if f.file_file_size > GIF_LIMIT
          [:gif_transcoder, :blurhash_transcoder]
        else
          [:lazy_thumbnail, :blurhash_transcoder]
        end
      elsif VIDEO_MIME_TYPES.include? f.file_content_type
        [:video_transcoder, :blurhash_transcoder]
      elsif AUDIO_MIME_TYPES.include? f.file_content_type
        [:audio_transcoder]
      elsif IMAGE_MIME_TYPES.include? f.file_content_type
        [:lazy_thumbnail, :blurhash_transcoder]
      end
    end
  end

  private

  def set_shortcode
    self.type = :unknown if file.blank? && !type_changed?

    return unless local?

    loop do
      self.shortcode = SecureRandom.urlsafe_base64(14)
      break if MediaAttachment.find_by(shortcode: shortcode).nil?
    end
  end

  def prepare_description
    self.description = description.strip[0...666] unless description.nil?
  end

  def set_file_name
    temp = file.queued_for_write[:original]
    unless temp.nil?
      orig = temp.original_filename
      ext = File.extname(orig).downcase
      name = File.basename(orig, '.*')
      self.file.instance_write(:file_name, "#{name}#{ext}")
    end
  end

  def set_type_and_extension
    self.type = VIDEO_MIME_TYPES.include?(file_content_type) ? :video :
      AUDIO_MIME_TYPES.include?(file_content_type) ? :audio :
      IMAGE_MIME_TYPES.include?(file_content_type) ? :image :
      :unknown
  end

  def set_meta
    meta = populate_meta
    return if meta == {}
    file.instance_write :meta, meta
  end

  def populate_meta
    meta = file.instance_read(:meta) || {}

    file.queued_for_write.each do |style, file|
      meta[style] = style == :small || image? ? image_geometry(file) : video_metadata(file)
    end

    meta
  end

  def image_geometry(file)
    width, height = FastImage.size(file.path)

    return {} if width.nil?

    {
      width:  width,
      height: height,
      size: "#{width}x#{height}",
      aspect: width.to_f / height.to_f,
    }
  end

  def video_metadata(file)
    movie = FFMPEG::Movie.new(file.path)

    return {} unless movie.valid?

    {
      width: movie.width,
      height: movie.height,
      frame_rate: movie.frame_rate,
      duration: movie.duration,
      bitrate: movie.bitrate,
    }
  end

  def reset_parent_cache
    return if status_id.nil?
    Rails.cache.delete("statuses/#{status_id}")
  end
end
