class Api::V1::Accounts::PlansController < Api::V1::Accounts::BaseController
  def show
    authorize(Current.account, :show_plan?)
    render json: build_payload
  end

  private

  def build_payload
    plan_name = Current.account.plan_name
    plan = PerfectCX::Plans.find(plan_name) if plan_name.present?

    {
      plan_name: plan_name,
      display_name: plan&.dig('display_name'),
      limits: build_limits(plan),
      features: Current.account.enabled_features.keys
    }
  end

  def build_limits(plan)
    source = plan&.dig('limits') || Current.account.limits || {}

    {
      agents: {
        allowed: source['agents'] || Current.account.usage_limits[:agents],
        consumed: Current.account.account_users.active.count
      },
      inboxes: {
        allowed: source['inboxes'] || Current.account.usage_limits[:inboxes],
        consumed: Current.account.inboxes.active.count
      },
      captain_responses: {
        allowed: source['captain_responses'].to_i,
        consumed: Current.account.custom_attributes&.dig('captain_responses_usage').to_i
      },
      captain_documents: {
        allowed: source['captain_documents'].to_i,
        consumed: Current.account.custom_attributes&.dig('captain_documents_usage').to_i
      }
    }
  end
end
