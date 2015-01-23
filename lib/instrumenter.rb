require 'active_support/notifications'
require 'active_support/log_subscriber'

module Instrumenter
  def self.instrument(target, prefix, klass = prefix.to_s.camelize.constantize)
    target.instance_eval do
      define_method :instrument do |action, payload, &block|
        ActiveSupport::Notifications.instrument("#{action}.#{prefix}", payload, &block)
      end
    end

    Maker.new(prefix, klass).define!
  end

  class Maker
    def initialize(prefix, klass)
      @prefix, @klass = prefix, klass

      @ns = Module.new
      klass.const_set 'Instrumentation', @ns
    end

    def define!
      define_log_subscriber!
      define_controller_runtime! if defined?(ActionController::Base)
      define_railtie! if defined?(Rails)
    end

    protected

      def define_log_subscriber!
        @subscriber = subscriber_implementation
        @ns.const_set 'LogSubscriber', @subscriber
      end

      def define_controller_runtime!
        @runtime = runtime_implementation
        @ns.const_set 'ControllerRuntime', @runtime
      end

      def define_railtie!
        prefix     = @prefix
        runtime    = @runtime
        subscriber = @subscriber

        @railtie = Class.new(::Rails::Railtie) do
          initializer "#{prefix}.setup_instrumentation" do
            subscriber.attach_to prefix
            ActiveSupport.on_load(:action_controller) { include runtime }
          end
        end

        @ns.const_set 'Railtie', @railtie
      end

    private

      def subscriber_implementation
        # LogSubscriber to log request URLs and timings
        #
        # h/t https://gist.github.com/566725
        #
        impl = Class.new(ActiveSupport::LogSubscriber) do
          def request(event)
            self.class.runtime += event.duration

            url = event.payload[:url]
            if event.payload[:params] && event.payload[:params].respond_to?(:to_param)
              url += '?' << event.payload[:params].to_param
            end

            info "  #{self.class.runtime_name}: %s %s (%.1fms) - cache %s" % [
              event.payload[:method].upcase,
              url,
              event.duration,
              event.payload[:cached] ? 'HIT' : 'MISS'
            ]
          end

          class << self
            def runtime=(value)
              Thread.current[@runtime_key] = value
            end

            def runtime
              Thread.current[@runtime_key] ||= 0
            end

            def reset_runtime
              rt, self.runtime = runtime, 0
              rt
            end

            attr_reader :runtime_name
          end
        end

        impl.tap do
          impl.instance_variable_set :@runtime_name, @klass.name
          impl.instance_variable_set :@runtime_key,  [@prefix, :runtime].join('_')
        end
      end

      def runtime_implementation
        attr_name  = [@prefix, :runtime].join('_')
        subscriber = @subscriber

        # ActionController Instrumentation to log time spent in
        # requests at the bottom of log messages.
        #
        impl = Module.new do
          extend ActiveSupport::Concern

          attr_internal attr_name

          define_method :append_info_to_payload do |payload|
            super(payload)
            payload[attr_name] = (send(attr_name) || 0) + subscriber.runtime
          end
          protected :append_info_to_payload

          define_method :cleanup_view_runtime do |&block|
            rt_before_render = subscriber.reset_runtime
            runtime = super(&block)
            rt_after_render = subscriber.reset_runtime
            send("#{attr_name}=", rt_before_render + rt_after_render)
            runtime - rt_after_render
          end
          protected :cleanup_view_runtime
        end

        impl.const_set(:ClassMethods, Module.new do
          define_method :log_process_action do |payload|
            messages, runtime = super(payload), payload[attr_name]
            messages << ("#{subscriber.runtime_name}: %.1fms" % runtime.to_f) if runtime
            messages
          end
        end)

        return impl
      end
  end

end
