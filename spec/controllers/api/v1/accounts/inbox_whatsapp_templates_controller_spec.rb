require 'rails_helper'

RSpec.describe Api::V1::Accounts::InboxWhatsappTemplatesController, type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
  let(:web_widget_inbox) { create(:inbox, account: account) }
  let(:mock_service) { instance_double(Whatsapp::TemplateManagementService) }

  before do
    create(:inbox_member, user: agent, inbox: whatsapp_inbox)
    allow(Whatsapp::TemplateManagementService).to receive(:new).and_return(mock_service)
  end

  describe 'GET /api/v1/accounts/{account.id}/inboxes/{inbox.id}/whatsapp_templates' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when not a WhatsApp Cloud channel' do
      it 'returns bad request' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{web_widget_inbox.id}/whatsapp_templates",
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when WhatsApp Cloud channel' do
      it 'returns list of templates' do
        allow(mock_service).to receive(:list_templates).and_return([
                                                                     { 'name' => 'hello', 'status' => 'APPROVED' },
                                                                     { 'name' => 'bye', 'status' => 'PENDING' }
                                                                   ])

        get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates",
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['templates'].length).to eq(2)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/inboxes/{inbox.id}/whatsapp_templates' do
    let(:valid_params) do
      {
        template: {
          name: 'test_template',
          language: 'en',
          category: 'UTILITY',
          components: [
            { type: 'BODY', text: 'Hello {{1}}!', example: { body_text: [['John']] } }
          ]
        }
      }
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates",
             params: valid_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when not a WhatsApp Cloud channel' do
      it 'returns bad request' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{web_widget_inbox.id}/whatsapp_templates",
             headers: admin.create_new_auth_token, params: valid_params, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when template creation succeeds' do
      it 'returns created with template details' do
        allow(mock_service).to receive(:create_template).and_return({
                                                                      success: true,
                                                                      template_id: '123',
                                                                      template_name: 'test_template',
                                                                      status: 'PENDING',
                                                                      language: 'en'
                                                                    })

        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates",
             headers: admin.create_new_auth_token, params: valid_params, as: :json

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['template']['template_id']).to eq('123')
      end
    end

    context 'when template creation fails' do
      it 'returns unprocessable entity with error' do
        error_body = { 'error' => { 'message' => 'Invalid parameter', 'code' => 100 } }.to_json
        allow(mock_service).to receive(:create_template).and_return({
                                                                      success: false,
                                                                      error: 'Template creation failed',
                                                                      response_body: error_body
                                                                    })

        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates",
             headers: admin.create_new_auth_token, params: valid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Invalid parameter')
      end
    end

    context 'when ArgumentError is raised' do
      it 'returns unprocessable entity' do
        allow(mock_service).to receive(:create_template).and_raise(ArgumentError, 'Template name is required')

        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates",
             headers: admin.create_new_auth_token, params: valid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Template name is required')
      end
    end

    context 'when template parameters are missing' do
      it 'returns unprocessable entity' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates",
             headers: admin.create_new_auth_token, params: {}, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Template parameters are required')
      end
    end

    it 'returns unauthorized for agents (requires administrator)' do
      post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates",
           headers: agent.create_new_auth_token, params: valid_params, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/inboxes/{inbox.id}/whatsapp_templates/{template_name}' do
    context 'when template exists' do
      it 'returns template details' do
        allow(mock_service).to receive(:get_template).with('hello_world').and_return(
          success: true,
          templates: [{ 'name' => 'hello_world', 'status' => 'APPROVED' }]
        )

        get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates/hello_world",
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
      end
    end

    context 'when template does not exist' do
      it 'returns not found' do
        allow(mock_service).to receive(:get_template).with('nonexistent').and_return({
                                                                                       success: false,
                                                                                       error: 'Template not found'
                                                                                     })

        get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates/nonexistent",
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/inboxes/{inbox.id}/whatsapp_templates/{template_name}' do
    context 'when deletion succeeds' do
      it 'returns success' do
        allow(mock_service).to receive(:delete_template).with('old_template').and_return({ success: true })

        delete "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates/old_template",
               headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['success']).to be true
      end
    end

    context 'when deletion fails' do
      it 'returns unprocessable entity' do
        allow(mock_service).to receive(:delete_template).with('old_template').and_return({
                                                                                           success: false,
                                                                                           response_body: 'Delete failed'
                                                                                         })

        delete "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates/old_template",
               headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'returns unauthorized for unauthenticated user' do
      delete "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/whatsapp_templates/old_template"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
