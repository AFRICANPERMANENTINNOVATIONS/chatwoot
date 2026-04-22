class Api::V1::Accounts::SubscriptionsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    render json: subscription_service.status
  end

  def plans
    render json: { plans: available_plans }
  end

  private

  def check_authorization
    authorize Current.account, :update?
  end

  def subscription_service
    @subscription_service ||= Perfectcx::SubscriptionService.new(Current.account)
  end

  def available_plans
    Perfectcx::SubscriptionService::PLANS.filter_map do |key, plan|
      next if key == 'trial'

      {
        id: key,
        label: plan[:label],
        agents: plan[:agents],
        price: plan[:price],
        price_formatted: plan[:price].positive? ? "#{plan[:price].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse} FCFA/mois" : 'Sur devis'
      }
    end
  end
end
