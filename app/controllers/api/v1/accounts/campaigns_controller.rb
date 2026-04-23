class Api::V1::Accounts::CampaignsController < Api::V1::Accounts::BaseController
  before_action :campaign, except: [:index, :create]
  before_action :check_authorization

  def index
    @campaigns = Current.account.campaigns
  end

  def show; end

  def create
    @campaign = Current.account.campaigns.create!(campaign_params)
  end

  def update
    @campaign.update!(campaign_params)
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  def audience_preview
    resolver = Campaigns::AudienceResolver.new(account: Current.account, audience: audience_preview_param)
    render json: { count: resolver.count }
  end

  private

  def campaign
    @campaign ||= Current.account.campaigns.find_by(display_id: params[:id])
  end

  def campaign_params
    permitted = params.require(:campaign).permit(:title, :description, :message, :enabled, :trigger_only_during_business_hours,
                                                 :inbox_id, :sender_id, :scheduled_at, trigger_rules: {}, template_params: {})
    permitted[:audience] = raw_audience if params.dig(:campaign, :audience).present?
    permitted
  end

  def raw_audience
    audience = params.require(:campaign)[:audience]
    Array(audience).map { |entry| normalize_audience_entry(entry) }
  end

  def audience_preview_param
    params.require(:audience)
    Array(params[:audience]).map { |entry| normalize_audience_entry(entry) }
  end

  def normalize_audience_entry(entry)
    entry = entry.to_unsafe_h if entry.respond_to?(:to_unsafe_h)
    entry.deep_stringify_keys
  end
end
