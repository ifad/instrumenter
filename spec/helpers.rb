# frozen_string_literal: true

module Helpers
  def klass
    described_class
  end

  def notification_event(duration:, payload:)
    instance_double(ActiveSupport::Notifications::Event, duration: duration, payload: payload)
  end

  def fake_railtie_base
    Class.new do
      class << self
        def initializer(name, &block)
          initializers[name] = block
        end

        def initializers
          @initializers ||= {}
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include Helpers

  config.after do
    Thread.current.keys.each do |key|
      Thread.current[key] = nil if key.to_s.match?(/\Arspec_.*_runtime\z/)
    end
  end
end
