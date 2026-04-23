class Campaigns::AudienceResolver
  pattr_initialize [:account!, :audience!]

  def contact_ids
    ids = Set.new
    entries = Array(audience)
    entries.each do |entry|
      entry = entry.with_indifferent_access if entry.respond_to?(:with_indifferent_access)
      case entry['type']
      when 'Label'
        ids.merge(resolve_label_ids(entry['id']))
      when 'Filter'
        ids.merge(resolve_filter_ids(entry['query']))
      end
    end
    ids.to_a
  end

  def count
    contact_ids.size
  end

  private

  def resolve_label_ids(label_id)
    label = account.labels.find_by(id: label_id)
    return [] unless label

    account.contacts.tagged_with([label.title], any: true).pluck(:id)
  end

  def resolve_filter_ids(query)
    return [] if Array(query).blank?

    params = ActionController::Parameters.new('payload' => query).permit!
    result = ::Contacts::FilterService.new(account, nil, params).perform
    result[:contacts].pluck(:id)
  rescue CustomExceptions::CustomFilter::InvalidAttribute,
         CustomExceptions::CustomFilter::InvalidOperator,
         CustomExceptions::CustomFilter::InvalidQueryOperator,
         CustomExceptions::CustomFilter::InvalidValue
    []
  end
end
