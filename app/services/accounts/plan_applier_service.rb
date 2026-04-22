class Accounts::PlanApplierService
  pattr_initialize [:account!, :plan_name!]

  class UnknownPlanError < StandardError; end

  # Returns a summary hash:
  #   {
  #     plan_name:       'pro',
  #     limits:          { 'agents' => 10, ... },
  #     features_enabled:  [...],
  #     features_disabled: [...],
  #     account_users:   { disabled: [id, ...], enabled: [id, ...] },
  #     inboxes:         { disabled: [id, ...], enabled: [id, ...] }
  #   }
  def perform
    plan = PerfectCX::Plans.find(plan_name)
    raise UnknownPlanError, "Unknown plan: #{plan_name}" if plan.nil?

    summary = { plan_name: plan_name.to_s, limits: plan['limits'] || {} }

    Account.transaction do
      apply_limits(plan)
      apply_plan_name(plan)
      summary.merge!(apply_features(plan))
      summary[:account_users] = reconcile_account_users(plan)
      summary[:inboxes] = reconcile_inboxes(plan)
      account.save!
    end

    summary
  end

  private

  def apply_limits(plan)
    account.limits = (account.limits || {}).merge(plan['limits'] || {})
  end

  def apply_plan_name(plan)
    attrs = account.custom_attributes || {}
    attrs['plan_name'] = plan_name.to_s
    attrs['plan_display_name'] = plan['display_name']
    account.custom_attributes = attrs
  end

  def apply_features(plan)
    all_features = PerfectCX::Plans.all_feature_names
    to_enable  = (plan['features'] || []) & all_features
    to_disable = all_features - to_enable

    account.disable_features(*to_disable) if to_disable.any?
    account.enable_features(*to_enable)  if to_enable.any?

    { features_enabled: to_enable, features_disabled: to_disable }
  end

  # Reconciles account_users so that active count == min(total, quota).
  # Surplus priority: non-admins before admins, then least-recently-active first.
  # Re-enable priority: most-recently-disabled first (LIFO).
  def reconcile_account_users(plan)
    quota = plan.dig('limits', 'agents').to_i
    relation = account.account_users
    total = relation.count
    target_active = [total, quota].min
    active_count = relation.active.count

    disabled_ids = []
    enabled_ids = []

    if active_count > target_active
      surplus = active_count - target_active
      disabled_ids = relation.active
                             .order(Arel.sql('role ASC, active_at ASC NULLS FIRST'))
                             .limit(surplus)
                             .pluck(:id)
      AccountUser.where(id: disabled_ids).update_all(disabled_at: Time.current) if disabled_ids.any?
    elsif active_count < target_active
      reserve = target_active - active_count
      enabled_ids = relation.disabled
                            .order(disabled_at: :desc)
                            .limit(reserve)
                            .pluck(:id)
      AccountUser.where(id: enabled_ids).update_all(disabled_at: nil) if enabled_ids.any?
    end

    { disabled: disabled_ids, enabled: enabled_ids }
  end

  def reconcile_inboxes(plan)
    quota = plan.dig('limits', 'inboxes').to_i
    relation = account.inboxes
    total = relation.count
    target_active = [total, quota].min
    active_count = relation.active.count

    disabled_ids = []
    enabled_ids = []

    if active_count > target_active
      surplus = active_count - target_active
      disabled_ids = relation.active
                             .order(updated_at: :asc)
                             .limit(surplus)
                             .pluck(:id)
      Inbox.where(id: disabled_ids).update_all(disabled_at: Time.current) if disabled_ids.any?
    elsif active_count < target_active
      reserve = target_active - active_count
      enabled_ids = relation.disabled
                            .order(disabled_at: :desc)
                            .limit(reserve)
                            .pluck(:id)
      Inbox.where(id: enabled_ids).update_all(disabled_at: nil) if enabled_ids.any?
    end

    { disabled: disabled_ids, enabled: enabled_ids }
  end
end
