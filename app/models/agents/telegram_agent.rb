require 'telegram/bot'
require 'open-uri'
require 'tempfile'

module Agents
  class TelegramAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!

    gem_dependency_check { defined?(Telegram) }

    description <<-MD
      #{'# Include `telegram-bot-ruby` in your Gemfile to use this Agent!' if dependencies_missing?}

      The Telegram Agent receives and collects events and sends them via [Telegram](https://telegram.org/).

      It is assumed that events have either a `text`, `photo`, `audio`, `document` or `video` key. You can use the EventFormattingAgent if your event does not provide these keys.

      The value of `text` key is sent as a plain text message.
      The value of `photo`, `audio`, `document` and `video` keys should be an url which contents are sent to you according to the type.

      **Setup**

      1. obtain an `auth_token` by [creating a new bot](https://telegram.me/botfather).
      2. [send a private message to your bot](https://telegram.me/YourHuginnBot)
      3. obtain your private `chat_id` [from the recently started conversation](https://api.telegram.org/bot<auth_token>/getUpdates)
    MD

    def default_options
      {
        auth_token: 'xxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        chat_id: 'xxxxxxxx'
      }
    end

    def validate_options
      errors.add(:base, 'auth_token is required') unless options['auth_token'].present?
      errors.add(:base, 'chat_id is required') unless options['chat_id'].present?
    end

    def working?
      received_event_without_error? && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        receive_event event
      end
    end

    private

    TELEGRAM_FIELDS = {
      text:     :send_message,
      photo:    :send_photo,
      audio:    :send_audio,
      document: :send_document,
      video:    :send_video
    }.freeze

    def receive_event(event)
      TELEGRAM_FIELDS.each do |field, method|
        payload = load_field event, field
        next unless payload
        send_telegram_message method, field => payload
      end
    end

    def send_telegram_message(method, params)
      params[:chat_id] = interpolated['chat_id']
      Telegram::Bot::Client.run interpolated['auth_token'] do |bot|
        bot.api.send method, params
      end
    end

    def load_field(event, field)
      payload = event.payload[field]
      return false unless payload.present?
      return payload if field == :text
      load_file payload
    end

    def load_file(url)
      file = Tempfile.new [File.basename(url), File.extname(url)]
      file.binmode
      file.write open(url).read
      file.rewind
      file
    end
  end
end
