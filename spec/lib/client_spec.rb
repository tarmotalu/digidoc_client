require 'spec_helper'

describe Digidoc::Client do
  describe "#authenticate" do
    before do
      @client = Digidoc::Client.new
      @response = @client.authenticate(phone: phone)
    end

    let(:phone) {}

    context '303' do
      let(:phone) { '+37200001' }

      it "returns error" do
        @response.faultstring.should == '303'
      end
    end

    context 'close_session' do
      it 'closes session' do
        @client.close_session
      end
    end
  end
end