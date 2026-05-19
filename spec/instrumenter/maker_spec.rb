# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Instrumenter::Maker do
  let(:prefix) { :rspec_client_requests }
  let(:client_class) { stub_const('RspecClientRequests', Class.new) }
  let(:maker) { klass.new(prefix, client_class) }
  let(:subscriber_class) { client_class::Instrumentation::LogSubscriber }

  describe '#define!' do
    subject(:define!) { maker.define! }

    it 'defines the instrumentation classes' do
      define!

      instrumentation = client_class::Instrumentation

      expect(instrumentation.const_defined?(:LogSubscriber, false)).to be(true)
      expect(instrumentation.const_defined?(:ControllerRuntime, false)).to be(true)
      expect(instrumentation.const_defined?(:Railtie, false)).to be(true)
      expect(subscriber_class.runtime_name).to eq(client_class.name)
      expect(client_class::Instrumentation::Railtie < Rails::Railtie).to be(true)
    end
  end

  describe 'generated log subscriber' do
    before do
      maker.define!
      allow(subscriber).to receive(:info)
    end

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
        params: nil,
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
    before { maker.define! }

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
    before { maker.define! }

    let(:railtie_class) { client_class::Instrumentation::Railtie }

    it 'registers the setup initializer on a Rails::Railtie subclass' do
      initializer = railtie_class.initializers.find { |entry| entry.name == 'rspec_client_requests.setup_instrumentation' }

      expect(initializer).not_to be_nil
    end
  end
end
