class Api::V1::Accounts::InboxWhatsappTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :validate_whatsapp_cloud_channel

  def index
    templates = template_service.list_templates
    render json: { templates: templates }
  end

  def show
    result = template_service.get_template(params[:template_name])

    if result[:success]
      render json: result
    else
      render json: { error: result[:error] }, status: :not_found
    end
  end

  def create
    result = template_service.create_template(permitted_template_params)

    if result[:success]
      render json: { template: result.except(:success) }, status: :created
    else
      render_failed_creation(result)
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing
    render json: { error: 'Template parameters are required' }, status: :unprocessable_entity
  end

  def destroy
    result = template_service.delete_template(params[:template_name])

    if result[:success]
      render json: { success: true }
    else
      render json: { error: 'Failed to delete template', details: result[:response_body] }, status: :unprocessable_entity
    end
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :update?
  end

  def validate_whatsapp_cloud_channel
    return if @inbox.channel_type == 'Channel::Whatsapp' && @inbox.channel&.provider == 'whatsapp_cloud'

    render json: { error: 'Template management is only available for WhatsApp Cloud channels' }, status: :bad_request
  end

  def template_service
    @template_service ||= Whatsapp::TemplateManagementService.new(@inbox.channel)
  end

  def permitted_template_params
    permitted = params.require(:template).permit(:name, :language, :category)
    permitted[:components] = params[:template][:components].map { |c| c.permit!.to_h } if params[:template][:components].present?
    permitted
  end

  def render_failed_creation(result)
    whatsapp_error = parse_whatsapp_error(result[:response_body])
    error_message = whatsapp_error[:user_message] || result[:error]

    render json: {
      error: error_message,
      details: whatsapp_error[:technical_details]
    }, status: :unprocessable_entity
  end

  def parse_whatsapp_error(response_body)
    return { user_message: nil, technical_details: nil } if response_body.blank?

    error_data = JSON.parse(response_body)
    whatsapp_error = error_data['error'] || {}

    {
      user_message: whatsapp_error['error_user_msg'] || whatsapp_error['message'],
      technical_details: {
        code: whatsapp_error['code'],
        subcode: whatsapp_error['error_subcode'],
        type: whatsapp_error['type']
      }.compact
    }
  rescue JSON::ParserError
    { user_message: nil, technical_details: response_body }
  end
end
