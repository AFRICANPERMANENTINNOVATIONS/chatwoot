class Webhooks::WhatsappController < ActionController::API
  include MetaTokenVerifyConcern

  def process_payload
    if inactive_whatsapp_number?
      Rails.logger.warn("Rejected webhook for inactive WhatsApp number: #{params[:phone_number]}")
      render json: { error: 'Inactive WhatsApp number' }, status: :unprocessable_entity
      return
    end

    Webhooks::WhatsappEventsJob.perform_later(params.to_unsafe_hash)
    head :ok
  end

  # Unified webhook — single URL for all WhatsApp numbers
  # Meta sends the phone_number_id in the payload, so we can route without it in the URL
  def verify_unified
    if valid_unified_token?(params['hub.verify_token'])
      Rails.logger.info('WhatsApp unified webhook verified')
      render json: params['hub.challenge']
    else
      render status: :unauthorized, json: { error: 'Error; wrong verify token' }
    end
  end

  def process_unified_payload
    Webhooks::WhatsappEventsJob.perform_later(params.to_unsafe_hash)
    head :ok
  end

  private

  def valid_token?(token)
    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])
    whatsapp_webhook_verify_token = channel.provider_config['webhook_verify_token'] if channel.present?
    token == whatsapp_webhook_verify_token if whatsapp_webhook_verify_token.present?
  end

  # For the unified webhook, check the token against all WhatsApp Cloud channels
  # since we don't know which channel the verification is for
  def valid_unified_token?(token)
    return false if token.blank?

    # Check global unified webhook token first
    unified_token = GlobalConfigService.load('WHATSAPP_WEBHOOK_VERIFY_TOKEN', '')
    return true if unified_token.present? && token == unified_token

    # Fallback: check if any channel has this verify token
    Channel::Whatsapp.where(provider: 'whatsapp_cloud').exists?(
      "provider_config->>'webhook_verify_token' = ?", token
    )
  end

  def inactive_whatsapp_number?
    phone_number = params[:phone_number]
    return false if phone_number.blank?

    inactive_numbers = GlobalConfig.get_value('INACTIVE_WHATSAPP_NUMBERS').to_s
    return false if inactive_numbers.blank?

    inactive_numbers_array = inactive_numbers.split(',').map(&:strip)
    inactive_numbers_array.include?(phone_number)
  end
end
