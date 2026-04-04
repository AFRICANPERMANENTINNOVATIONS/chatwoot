require 'rails_helper'

describe Whatsapp::TemplateManagementService do
  let(:account) { create(:account) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              validate_provider_config: false, sync_templates: false)
  end
  let(:service) { described_class.new(whatsapp_channel) }
  let(:api_key) { whatsapp_channel.provider_config['api_key'] }
  let(:business_account_id) { whatsapp_channel.provider_config['business_account_id'] }
  let(:base_url) { "https://graph.facebook.com/v14.0/#{business_account_id}" }

  describe '#create_template' do
    let(:template_params) do
      {
        name: 'hello_world',
        language: 'en',
        category: 'UTILITY',
        components: [
          { 'type' => 'BODY', 'text' => 'Hello {{1}}, welcome!', 'example' => { 'body_text' => [['John']] } }
        ]
      }
    end

    context 'when template name is invalid' do
      it 'raises error for blank name' do
        expect { service.create_template(name: '') }.to raise_error(ArgumentError, 'Template name is required')
      end

      it 'raises error for name with invalid characters' do
        expect { service.create_template(name: 'Hello World') }
          .to raise_error(ArgumentError, 'Template name must contain only lowercase letters, numbers, and underscores')
      end
    end

    context 'when Meta API succeeds' do
      before do
        stub_request(:post, "#{base_url}/message_templates")
          .to_return(
            status: 200,
            body: { id: '123456', name: 'hello_world', status: 'PENDING' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns success with template details' do
        result = service.create_template(template_params)

        expect(result[:success]).to be true
        expect(result[:template_id]).to eq('123456')
        expect(result[:template_name]).to eq('hello_world')
        expect(result[:status]).to eq('PENDING')
      end
    end

    context 'when Meta API fails' do
      before do
        stub_request(:post, "#{base_url}/message_templates")
          .to_return(
            status: 400,
            body: { error: { message: 'Invalid template', code: 100 } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns failure with error details' do
        result = service.create_template(template_params)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Template creation failed')
      end
    end

    context 'when template has a media header' do
      let(:media_template_params) do
        {
          name: 'promo_image',
          language: 'en',
          category: 'MARKETING',
          components: [
            { 'type' => 'HEADER', 'format' => 'IMAGE', 'example' => { 'media_url' => 'https://example.com/image.png' } },
            { 'type' => 'BODY', 'text' => 'Check this out!' }
          ]
        }
      end

      before do
        allow(GlobalConfigService).to receive(:load).with('WHATSAPP_APP_ID', '').and_return('999888777')
      end

      it 'raises error when WHATSAPP_APP_ID is not configured' do
        allow(GlobalConfigService).to receive(:load).with('WHATSAPP_APP_ID', '').and_return('')

        stub_request(:get, 'https://example.com/image.png')
          .to_return(status: 200, body: 'fake_image_data')

        expect { service.create_template(media_template_params) }
          .to raise_error(ArgumentError, /WHATSAPP_APP_ID is not configured/)
      end

      it 'uploads media and creates template with header_handle' do
        stub_request(:get, 'https://example.com/image.png')
          .to_return(status: 200, body: 'fake_image_data')

        stub_request(:post, 'https://graph.facebook.com/v14.0/999888777/uploads')
          .to_return(status: 200, body: { id: 'upload_session_123' }.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:post, 'https://graph.facebook.com/v14.0/upload_session_123')
          .to_return(status: 200, body: { h: 'handle_abc123' }.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:post, "#{base_url}/message_templates")
          .to_return(status: 200, body: { id: '789', name: 'promo_image', status: 'PENDING' }.to_json,
                     headers: { 'Content-Type' => 'application/json' })

        result = service.create_template(media_template_params)

        expect(result[:success]).to be true
        expect(result[:template_id]).to eq('789')
      end

      it 'raises error when media URL is blank' do
        params = media_template_params.deep_dup
        params[:components][0]['example']['media_url'] = ''

        expect { service.create_template(params) }
          .to raise_error(ArgumentError, 'Media URL is required for media header templates')
      end

      it 'raises error when media download fails' do
        stub_request(:get, 'https://example.com/image.png')
          .to_return(status: 404, body: 'Not Found')

        expect { service.create_template(media_template_params) }
          .to raise_error(ArgumentError, /Failed to download media/)
      end
    end
  end

  describe '#delete_template' do
    it 'returns success when Meta API succeeds' do
      stub_request(:delete, "#{base_url}/message_templates?name=hello_world")
        .to_return(status: 200, body: { success: true }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.delete_template('hello_world')
      expect(result[:success]).to be true
    end

    it 'returns failure when Meta API fails' do
      stub_request(:delete, "#{base_url}/message_templates?name=nonexistent")
        .to_return(status: 404, body: { error: { message: 'Not found' } }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.delete_template('nonexistent')
      expect(result[:success]).to be false
    end
  end

  describe '#list_templates' do
    it 'returns all templates' do
      stub_request(:get, "#{base_url}/message_templates?access_token=#{api_key}")
        .to_return(
          status: 200,
          body: { data: [{ name: 'template_1' }, { name: 'template_2' }] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = service.list_templates
      expect(result.length).to eq(2)
      expect(result.first['name']).to eq('template_1')
    end

    it 'handles paginated results' do
      stub_request(:get, "#{base_url}/message_templates?access_token=#{api_key}")
        .to_return(
          status: 200,
          body: { data: [{ name: 'page1' }], paging: { next: 'https://graph.facebook.com/next_page' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, 'https://graph.facebook.com/next_page')
        .to_return(
          status: 200,
          body: { data: [{ name: 'page2' }] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = service.list_templates
      expect(result.length).to eq(2)
    end

    it 'returns empty array on API failure' do
      stub_request(:get, "#{base_url}/message_templates?access_token=#{api_key}")
        .to_return(status: 500, body: 'Internal Server Error')

      expect(service.list_templates).to eq([])
    end
  end

  describe '#get_template' do
    it 'returns template when found' do
      stub_request(:get, "#{base_url}/message_templates?name=hello_world")
        .to_return(
          status: 200,
          body: { data: [{ name: 'hello_world', status: 'APPROVED' }] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = service.get_template('hello_world')
      expect(result[:success]).to be true
      expect(result[:templates].first['status']).to eq('APPROVED')
    end

    it 'returns not found when template does not exist' do
      stub_request(:get, "#{base_url}/message_templates?name=nonexistent")
        .to_return(status: 200, body: { data: [] }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.get_template('nonexistent')
      expect(result[:success]).to be false
      expect(result[:error]).to eq('Template not found')
    end
  end
end
