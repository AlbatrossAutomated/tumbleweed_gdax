# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RequestUsher do
  let(:request_method) { 'quote' }
  let(:resp) { file_fixture("#{request_method}.json").read }
  let(:parsed_resp) { JSON.parse(resp) }
  let(:msg_partial) { 'No way Jose!' }
  let(:not_found_err) { 'NotFound' }

  describe '.execute' do
    subject { RequestUsher.execute(request_method) }

    context 'pre-request handling' do
      after { subject }

      it 'calls for throttling requests' do
        expect(RequestUsher).to receive(:throttle)
      end

      it 'calls for making the request' do
        allow(Request).to receive(:send) { resp }
        expect(Request).to receive(:send).with(request_method)
      end
    end

    context 'successful requests' do
      let(:first_request_time) { Time.zone.now }

      it 'sets the request time' do
        subject
        expect(RequestUsher.last_request_time.to_s).not_to be_empty
      end

      it 'returns the exchange API response as parsed JSON' do
        expect(subject).to eq parsed_resp
      end

      it 'sets last_request_time between requests' do
        RequestUsher.last_request_time = first_request_time
        subject
        diff = RequestUsher.last_request_time - first_request_time
        expect(diff.positive?).to be true
      end
    end

    context 'unsuccessful requests' do
      let(:err_class) { Coinbase::Exchange::APIError }
      let(:log_msg) { "API ERROR! Msg: #{raised_error}, Class: #{err_class}. " }

      before do
        allow(Bot).to receive(:log)

        count = 0
        allow(Request).to receive(request_method) do
          count += 1
          raise(err_class, raised_error) unless count > 1

          resp if count == 2
        end
      end

      context 'the error is NotFound' do
        let(:raised_error) { { message: not_found_err }.to_json }

        it 'logs the error' do
          expect(Bot).to receive(:log).with(log_msg, an_instance_of(err_class), :error)
          subject
        end

        it 'returns the error in a parsed format' do
          expect(subject).to eq JSON.parse(raised_error)
        end
      end

      context 'the error is retriable' do
        let(:raised_error) { { message: msg_partial }.to_json }
        let(:first_request_time) { Time.zone.now }

        before { RequestUsher.last_request_time = first_request_time }

        context 'JSON formatted error' do
          it 'logs the error' do
            expect(Bot).to receive(:log).with(log_msg, an_instance_of(err_class), :error)
            subject
          end

          it 'retries the request' do
            expect(Request).to receive(request_method).exactly(:twice)
            subject
          end

          it 'returns the API response after successful retry' do
            expect(subject).to eq parsed_resp
          end
        end

        context 'non-JSON string formatted error' do
          let(:raised_error) { msg_partial }

          it 'logs the error' do
            expect(Bot).to receive(:log).with(log_msg, an_instance_of(err_class), :error)
            subject
          end

          it 'retries the request' do
            expect(Request).to receive(request_method).exactly(:twice)
            subject
          end

          it 'returns the API response after successful retry' do
            expect(subject).to eq parsed_resp
          end
        end

        context 'HTML formatted error' do
          let(:raised_error) { file_fixture('html_error.html').read }
          let(:err_class) { JSON::ParserError }
          let(:log_msg) do
            "API ERROR! Msg: 765: unexpected token at '#{raised_error}', Class: #{err_class}. "
          end

          before do
            allow(Request).to receive(request_method) { raised_error }
            allow(RequestUsher).to receive(:pass_thru_error?)
              .and_return(false, true, false)
          end

          it 'logs the error' do
            expect(Bot).to receive(:log).with(log_msg, an_instance_of(err_class), :error)
            subject
          end

          it 'retries the request' do
            expect(Request).to receive(request_method).exactly(:twice)
            subject
          end
        end

        context 'any error format' do
          it 'it throttles the retry request' do
            expect(RequestUsher).to receive(:throttle).exactly(:twice)
            subject
          end

          it 'sets last_request_time between retries' do
            subject
            diff = RequestUsher.last_request_time - first_request_time
            expect(diff.positive?).to be true
          end
        end
      end
    end
  end

  describe '.throttle' do
    let(:first_request_time) { Time.zone.now }

    before do
      RequestUsher.last_request_time = first_request_time
      ENV['THROTTLE_MIN'] = '0.35' # override env.test
    end

    after { ENV['THROTTLE_MIN'] = '0.0' } # unset

    it "throttles with respect to the exchange's API rules" do
      RequestUsher.execute(request_method)
      expect(RequestUsher.last_request_time - first_request_time)
        .to be >= ENV['THROTTLE_MIN'].to_f
    end
  end

  describe '.format_error' do
    let(:json) { { message: 'bar' }.to_json }
    let(:not_json) { 'HUZZAH!!' }
    let(:not_json_result) { { 'message' => not_json } }

    it 'parses JSON errors' do
      expect(RequestUsher.format_error(json)).to eq JSON.parse(json)
    end

    it 'it returns a hash for non-JSON errors' do
      expect(RequestUsher.format_error(not_json)).to eq not_json_result
    end
  end

  describe '.pass_thru_error?' do
    let(:retriable_json) { { message: msg_partial }.to_json }
    let(:not_found_json) { { message: not_found_err }.to_json }
    let(:retriable_non_json) { msg_partial }
    let(:not_found_non_json) { not_found_err }

    context 'JSON error' do
      it 'returns true for NotFound error' do
        expect(RequestUsher.pass_thru_error?(not_found_json)).to be true
      end

      it 'returns false for errors other than NotFound' do
        expect(RequestUsher.pass_thru_error?(retriable_json)).to be false
      end
    end

    context 'non-JSON error' do
      it 'returns true for NotFound error' do
        expect(RequestUsher.pass_thru_error?(not_found_non_json)).to be true
      end

      it 'returns false for errors other than NotFound' do
        expect(RequestUsher.pass_thru_error?(retriable_non_json)).to be false
      end
    end
  end
end
