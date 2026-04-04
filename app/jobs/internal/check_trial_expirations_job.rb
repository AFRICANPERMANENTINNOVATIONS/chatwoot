class Internal::CheckTrialExpirationsJob < ApplicationJob
  queue_as :scheduled_jobs

  WARNING_DAYS = [2, 1, 0].freeze

  def perform
    Account.where(status: :active).find_each do |account|
      service = Perfectcx::SubscriptionService.new(account)
      next if service.current_plan == 'enterprise'
      next if service.subscription_expires_at.blank?

      days = service.days_remaining

      if days.zero? && !service.subscription_active?
        service.suspend
        notify_expired(account)
      elsif WARNING_DAYS.include?(days)
        notify_expiring(account, days)
      end
    end
  end

  private

  def notify_expiring(account, days_remaining)
    account.administrators.each do |admin|
      TrialNotificationMailer.trial_expiring(
        account: account, user: admin, days_remaining: days_remaining
      ).deliver_later
    end
  end

  def notify_expired(account)
    account.administrators.each do |admin|
      TrialNotificationMailer.trial_expired(account: account, user: admin).deliver_later
    end
  end
end
