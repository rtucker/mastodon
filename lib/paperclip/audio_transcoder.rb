# frozen_string_literal: true

module Paperclip
  class AudioTranscoder < Paperclip::Processor
    def make
      max_aud_len = (ENV['MAX_AUDIO_LENGTH'] || 60.0).to_f

      meta = ::Av.cli.identify(@file.path)
      #attachment.instance.file_file_name    = 'media.m4a'
      #attachment.instance.file_content_type = 'audio/mp4'
      attachment.instance.type              = MediaAttachment.types[:video]

      Paperclip::Transcoder.make(file, options, attachment)
    end
  end
end
