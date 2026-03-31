class Webhooks::PaymentController < ActionController::API
  def process_payload
    result = process_event
    render json: result[:body], status: result[:status]
  rescue JSON::ParserError
    render json: { error: 'Invalid JSON' }, status: :bad_request
  rescue StandardError => e
    Rails.logger.error "Payment webhook error: #{e.message}"
    render json: { error: 'Internal error' }, status: :internal_server_error
  end

  private

  def process_event
    event = JSON.parse(request.body.read)
    handler = Perfectcx::PaymentWebhookService.new(event, request.headers)
    result = handler.process

    if result[:success]
      { body: { status: 'ok' }, status: :ok }
    else
      Rails.logger.error "Payment webhook failed: #{result[:error]}"
      { body: { error: result[:error] }, status: :unprocessable_entity }
    end
  end
end
