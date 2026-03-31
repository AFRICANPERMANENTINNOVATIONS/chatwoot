class Perfectcx::SubscriptionService
  PLANS = {
    'trial' => { agents: 2, price: 0, duration_days: 7 },
    'pro_2' => { agents: 2, price: 15_000, label: 'Pro — 2 agents' },
    'pro_5' => { agents: 5, price: 60_000, label: 'Pro — 5 agents' },
    'pro_10' => { agents: 10, price: 100_000, label: 'Pro — 10 agents' },
    'pro_25' => { agents: 25, price: 200_000, label: 'Pro — 25 agents' },
    'enterprise' => { agents: 999_999, price: 0, label: 'Enterprise' }
  }.freeze

  def initialize(account)
    @account = account
  end

  def current_plan
    @account.custom_attributes['plan_name'] || 'trial'
  end

  def plan_details
    PLANS[current_plan] || PLANS['trial']
  end

  def subscription_active?
    return true if current_plan == 'enterprise'

    expires = subscription_expires_at
    return false if expires.blank?

    Time.current < expires
  end

  def subscription_expires_at
    raw = @account.custom_attributes['subscription_expires_at']
    return nil if raw.blank?

    Time.zone.parse(raw)
  rescue ArgumentError
    nil
  end

  def days_remaining
    expires = subscription_expires_at
    return 0 if expires.blank?

    [(expires.to_date - Time.current.to_date).to_i, 0].max
  end

  def activate_plan(plan_name, months: 1, payment_reference: nil)
    plan = PLANS[plan_name]
    raise ArgumentError, "Unknown plan: #{plan_name}" unless plan

    expires_at = (Time.current + months.months).iso8601
    persist_plan(plan_name, plan, expires_at, payment_reference)

    Rails.logger.info("Subscription activated: Account ##{@account.id} — plan=#{plan_name}, expires=#{expires_at}")
    { success: true, plan: plan_name, expires_at: expires_at }
  end

  def persist_plan(plan_name, plan, expires_at, payment_reference)
    @account.reload
    attrs = @account.custom_attributes.merge(
      'plan_name' => plan_name, 'subscription_expires_at' => expires_at,
      'subscription_status' => 'active', 'last_payment_reference' => payment_reference,
      'last_payment_at' => Time.current.iso8601, 'subscribed_quantity' => plan[:agents]
    )
    @account.update!(custom_attributes: attrs, status: :active, limits: { 'agents' => plan[:agents], 'inboxes' => 999_999 })
  end

  def renew(months: 1, payment_reference: nil)
    plan_name = current_plan
    plan_name = 'pro_2' if plan_name == 'trial'

    base_time = subscription_active? ? subscription_expires_at : Time.current
    expires_at = (base_time + months.months).iso8601

    @account.reload
    attrs = @account.custom_attributes.merge(
      'plan_name' => plan_name,
      'subscription_expires_at' => expires_at,
      'subscription_status' => 'active',
      'last_payment_reference' => payment_reference,
      'last_payment_at' => Time.current.iso8601
    )
    @account.update!(custom_attributes: attrs, status: :active)

    Rails.logger.info("Subscription renewed: Account ##{@account.id} — expires=#{expires_at}, ref=#{payment_reference}")

    { success: true, plan: plan_name, expires_at: expires_at }
  end

  def suspend
    @account.reload
    attrs = @account.custom_attributes.merge('subscription_status' => 'suspended')
    @account.update!(custom_attributes: attrs, status: :suspended)

    Rails.logger.info("Subscription suspended: Account ##{@account.id}")

    { success: true }
  end

  def status
    {
      plan: current_plan,
      plan_label: plan_details[:label] || current_plan,
      agents_limit: plan_details[:agents],
      agents_used: @account.users.count,
      price: plan_details[:price],
      active: subscription_active?,
      expires_at: subscription_expires_at&.iso8601,
      days_remaining: days_remaining,
      status: @account.custom_attributes['subscription_status'] || 'trial'
    }
  end
end
