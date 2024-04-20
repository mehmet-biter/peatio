# encoding: UTF-8
# frozen_string_literal: true

require File.join(ENV.fetch('RAILS_ROOT'), 'config', 'environment')

raise "bindings must be provided." if ARGV.size == 0

logger = Rails.logger

consumer = ::Stream.consumer

at_exit { consumer.stop }

def get_worker(id)
  ::Workers::Engines.const_get(id.to_s.camelize).new
end

workers = []
ARGV.each do |id|
  worker = get_worker(id)

  consumer.subscribe(id)
  consumer.each_message(automatically_mark_as_processed: false) do |message|
    logger.info { "Received: #{message.value}" }
    begin
      payload = JSON.parse(message.value)

      worker.process(payload)

      consumer.mark_message_as_processed(message)
    rescue StandardError => e
      if worker.is_db_connection_error?(e)
        logger.error(db: :unhealthy, message: e.message)
        exit(1)
      end

      report_exception(e)
    end
  end

  workers << worker
end

%w(USR1 USR2).each do |signal|
  Signal.trap(signal) do
    puts "#{signal} received."
    handler = "on_#{signal.downcase}"
    workers.each {|w| w.send handler if w.respond_to?(handler) }
  end
end
