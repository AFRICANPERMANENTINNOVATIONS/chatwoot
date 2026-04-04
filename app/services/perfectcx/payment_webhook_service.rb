class Perfectcx::PaymentWebhookService
  # Generic payment webhook handler
  # Adapt this when integrating your payment provider
  #
  # Expected payload:
  # {
  #   "event": "payment.success" | "payment.failed",
  #   "account_id": 1,
  #   "plan": "pro_2",
  #   "months": 1,
  #   "amount": 15000,
  #   "currency": "XOF",
  #   "reference": "txn_abc123"
  # }

  def initialize(payload, headers = {})
    @payload = payload.with_indifferent_access
    @headers = headers
  end

  def process
    verify_signature!

    case event_type
    when 'payment.success', 'charge.completed', 'transaction.success'
      handle_payment_success
    when 'payment.failed', 'charge.failed', 'transaction.failed'
      handle_payment_failed
    else
      Rails.logger.warn "Unhandled payment event: #{event_type}"
      { success: true, message: 'Event ignored' }
    end
  end

  private

  def event_type
    @payload['event'] || @payload['type'] || @payload['status']
  end

  def verify_signature!
    secret = ENV.fetch('PAYMENT_WEBHOOK_SECRET', nil)
    return if secret.blank? # Skip verification if no secret configured (dev mode)

    signature = @headers['X-Webhook-Signature'] || @headers['HTTP_X_WEBHOOK_SIGNATURE']
    raise 'Missing webhook signature' if signature.blank?

    expected = OpenSSL::HMAC.hexdigest('SHA256', secret, @payload.to_json)
    raise 'Invalid webhook signature' unless ActiveSupport::SecurityUtils.secure_compare(signature, expected)
  end

  def handle_payment_success
    account = find_account
    return { success: false, error: 'Account not found' } unless account

    plan = @payload['plan'] || 'pro_2'
    months = (@payload['months'] || 1).to_i
    reference = @payload['reference'] || @payload['transaction_id'] || @payload['id']

    service = Perfectcx::SubscriptionService.new(account)
    result = service.activate_plan(plan, months: months, payment_reference: reference)

    notify_admins(account, plan, months)

    result
  rescue ArgumentError => e
    { success: false, error: e.message }
  end

  def handle_payment_failed
    reference = @payload['reference'] || @payload['transaction_id']
    Rails.logger.warn "Payment failed: ref=#{reference}, account=#{@payload['account_id']}"

    { success: true, message: 'Payment failure recorded' }
  end

  def find_account
    if @payload['account_id'].present?
      Account.find_by(id: @payload['account_id'])
    elsif @payload['email'].present?
      User.from_email(@payload['email'])&.accounts&.first
    end
  end

  def notify_admins(account, plan, months)
    plan_details = Perfectcx::SubscriptionService::PLANS[plan]
    label = plan_details&.fetch(:label, plan) || plan

    account.administrators.each do |admin|
      TrialNotificationMailer.subscription_activated(
        account: account,
        user: admin,
        plan_label: label,
        months: months
      ).deliver_later
    end
  rescue StandardError => e
    Rails.logger.error "Failed to notify admins: #{e.message}"
  end
end
