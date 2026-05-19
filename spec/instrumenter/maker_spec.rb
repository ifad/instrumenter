# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Instrumenter::Maker do
  let(:prefix) { :rspec_client_requests }
  let(:client_class) { stub_const('RspecClientRequests', Class.new) }
  let(:maker) { klass.new(prefix, client_class) }

  describe '#define!' do
    subject(:define!) { maker.define! }

    it 'defines a log subscriber under the instrumentation namespace' do
      define!

      instrumentation = client_class::Instrumentation

      expect(instrumentation.const_defined?(:LogSubscriber, false)).to be(true)
      expect(instrumentation::LogSubscriber.runtime_name).to eq(client_class.name)
    end

    context 'when ActionController and Rails are defined' do
      before do
        stub_const('ActionController', Module.new)
        stub_const('ActionController::Base', Class.new)
        stub_const('Rails', Module.new)
        stub_const('Rails::Railtie', fake_railtie_base)
      end

      it 'defines controller runtime and railtie support' do
        define!

        instrumentation = client_class::Instrumentation

        expect(instrumentation.const_defined?(:ControllerRuntime, false)).to be(true)
        expect(instrumentation.const_defined?(:Railtie, false)).to be(true)
      end
    end
  end

  describe 'generated log subscriber' do
    before do
      maker.define!
      allow(subscriber).to receive(:info)
    end

    let(:subscriber_class) { client_class::Instrumentation::LogSubscriber }
    let(:subscriber) { subscriber_class.new }

    it 'formats request logs with query params and a cache miss' do
      params = Class.new do
        def initialize(value)
          @value = value
        end

        def to_param
          @value
        end
      end.new('page=2')

      payload = {
        method: 'get',
        url: 'https://example.test/people',
        params: params,
        cached: false
      }
      event = notification_event(duration: 12.4, payload: payload)

      subscriber.request(event)

      expect(subscriber).to have_received(:info).with('  RspecClientRequests: GET https://example.test/people?page=2 (12.4ms) - cache MISS')
      expect(subscriber_class.runtime).to eq(12.4)
    end

    it 'formats request logs without params and reports cache hits' do
      payload = {
        method: 'post',
        url: 'https://example.test/people',
        params: Object.new,
        cached: true
      }
      event = notification_event(duration: 8.3, payload: payload)

      subscriber.request(event)

      expect(subscriber).to have_received(:info).with('  RspecClientRequests: POST https://example.test/people (8.3ms) - cache HIT')
    end

    it 'returns and clears the accumulated runtime' do
      first_event = notification_event(
        duration: 2.5,
        payload: { method: 'get', url: 'https://example.test/people', cached: false }
      )
      second_event = notification_event(
        duration: 3.0,
        payload: { method: 'get', url: 'https://example.test/people', cached: false }
      )

      subscriber.request(first_event)
      subscriber.request(second_event)

      expect(subscriber_class.reset_runtime).to eq(5.5)
      expect(subscriber_class.runtime).to eq(0)
    end
  end

  describe 'generated controller runtime' do
    before do
      stub_const('ActionController', Module.new)
      stub_const('ActionController::Base', Class.new)
      maker.define!
    end

    let(:subscriber_class) { client_class::Instrumentation::LogSubscriber }
    let(:runtime_module) { client_class::Instrumentation::ControllerRuntime }
    let(:base_controller) do
      Class.new do
        def append_info_to_payload(payload)
          payload[:base] = true
        end

        def cleanup_view_runtime
          yield if block_given?
          20.0
        end

        def self.log_process_action(_payload)
          ['Completed 200 OK']
        end
      end
    end
    let(:controller_class) do
      runtime = runtime_module

      Class.new(base_controller) do
        include runtime
      end
    end
    let(:controller) { controller_class.new }

    it 'adds subscriber runtime to the payload' do
      subscriber_class.runtime = 6.5
      controller.send("#{prefix}_runtime=", 4.0)

      payload = {}
      controller.send(:append_info_to_payload, payload)

      expect(payload).to eq(base: true, 'rspec_client_requests_runtime' => 10.5)
    end

    it 'stores render runtime and subtracts it from the returned total' do
      subscriber_class.runtime = 7.0

      result = controller.send(:cleanup_view_runtime) do
        subscriber_class.runtime = 3.5
      end

      expect(result).to eq(16.5)
      expect(controller.send("#{prefix}_runtime")).to eq(10.5)
      expect(subscriber_class.runtime).to eq(0)
    end

    it 'appends the runtime summary to process action messages' do
      messages = controller_class.log_process_action('rspec_client_requests_runtime' => 10.5)

      expect(messages).to eq(['Completed 200 OK', 'RspecClientRequests: 10.5ms'])
    end
  end

  describe 'generated railtie' do
    let(:on_load_hooks) { {} }
    let(:subscriber_class) { client_class::Instrumentation::LogSubscriber }
    let(:runtime_module) { client_class::Instrumentation::ControllerRuntime }
    let(:railtie_class) { client_class::Instrumentation::Railtie }

    before do
      stub_const('ActionController', Module.new)
      stub_const('ActionController::Base', Class.new)
      stub_const('Rails', Module.new)
      stub_const('Rails::Railtie', fake_railtie_base)
      allow(ActiveSupport).to receive(:on_load) do |name, &block|
        on_load_hooks[name] = block
      end
      maker.define!
    end

    it 'registers the setup initializer' do
      expect(railtie_class.initializers.keys).to contain_exactly('rspec_client_requests.setup_instrumentation')
    end

    it 'attaches the subscriber and includes controller runtime on load' do
      allow(subscriber_class).to receive(:attach_to)

      railtie_class.initializers.fetch('rspec_client_requests.setup_instrumentation').call

      expect(subscriber_class).to have_received(:attach_to).with(:rspec_client_requests)
      expect(on_load_hooks.keys).to contain_exactly(:action_controller)

      controller_host = Class.new
      controller_host.class_eval(&on_load_hooks.fetch(:action_controller))

      expect(controller_host.ancestors).to include(runtime_module)
    end
  end
end
