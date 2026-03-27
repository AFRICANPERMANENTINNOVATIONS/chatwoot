class Whatsapp::TemplateManagementService
  WHATSAPP_API_VERSION = 'v14.0'.freeze
  MEDIA_HEADER_FORMATS = %w[IMAGE VIDEO DOCUMENT].freeze

  MEDIA_CONTENT_TYPES = {
    'image' => 'image/png',
    'video' => 'video/mp4',
    'document' => 'application/pdf'
  }.freeze

  def initialize(whatsapp_channel)
    @whatsapp_channel = whatsapp_channel
  end

  def create_template(params)
    validate_template_name!(params[:name])
    components = params[:components] || []
    components = process_media_header(components) if media_header?(components)
    response = post_template(params, components)
    parse_create_response(response, params)
  end

  def delete_template(template_name)
    response = HTTParty.delete(
      "#{business_account_path}/message_templates?name=#{template_name}",
      headers: api_headers
    )
    { success: response.success?, response_body: response.body }
  end

  def list_templates
    fetch_all_templates(
      "#{business_account_path}/message_templates?access_token=#{@whatsapp_channel.provider_config['api_key']}"
    )
  end

  def get_template(template_name)
    response = HTTParty.get(
      "#{business_account_path}/message_templates?name=#{template_name}",
      headers: api_headers
    )

    if response.success? && response['data']&.any?
      { success: true, templates: response['data'] }
    else
      { success: false, error: 'Template not found' }
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching template: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def post_template(params, components)
    HTTParty.post(
      "#{business_account_path}/message_templates",
      headers: api_headers,
      body: {
        name: params[:name],
        language: params[:language] || 'en',
        category: params[:category] || 'UTILITY',
        components: components
      }.to_json
    )
  end

  def parse_create_response(response, params)
    if response.success?
      { success: true, template_id: response['id'], template_name: response['name'] || params[:name],
        status: response['status'] || 'PENDING', language: params[:language] || 'en' }
    else
      Rails.logger.error "WhatsApp template creation failed: #{response.code} - #{response.body}"
      { success: false, error: 'Template creation failed', response_body: response.body }
    end
  end

  def media_header?(components)
    header = components.find { |c| c['type'] == 'HEADER' || c[:type] == 'HEADER' }
    return false unless header

    format = header['format'] || header[:format]
    MEDIA_HEADER_FORMATS.include?(format&.upcase)
  end

  def process_media_header(components)
    components.map do |component|
      comp = (component.is_a?(ActionController::Parameters) ? component.to_unsafe_h : component).deep_symbolize_keys
      next component unless comp[:type] == 'HEADER' && MEDIA_HEADER_FORMATS.include?(comp[:format]&.upcase)

      build_media_header_component(comp)
    end
  end

  def build_media_header_component(comp)
    media_url = comp.dig(:example, :media_url)
    raise ArgumentError, 'Media URL is required for media header templates' if media_url.blank?

    handle = upload_media_to_meta(media_url, comp[:format].downcase)
    raise ArgumentError, 'Failed to upload media to Meta' if handle.blank?

    { type: 'HEADER', format: comp[:format].upcase, example: { header_handle: [handle] } }
  end

  def upload_media_to_meta(media_url, media_type)
    blob = find_active_storage_blob(media_url)
    file_data = blob ? blob.download : download_file(media_url)
    content_type = blob ? blob.content_type : (MEDIA_CONTENT_TYPES[media_type] || 'application/octet-stream')
    raise ArgumentError, "Failed to download media from #{media_url}" if file_data.blank?

    app_id = @whatsapp_channel.provider_config['app_id'].presence || GlobalConfigService.load('WHATSAPP_APP_ID', '')
    raise ArgumentError, 'WHATSAPP_APP_ID is not configured' if app_id.blank?

    session_id = create_upload_session(app_id, file_data.bytesize, content_type)
    upload_file_bytes(session_id, file_data, content_type)
  end

  def create_upload_session(app_id, file_length, content_type)
    response = HTTParty.post(
      "#{api_base_path}/#{WHATSAPP_API_VERSION}/#{app_id}/uploads",
      headers: api_headers,
      body: { file_length: file_length, file_type: content_type }.to_json
    )

    unless response.success? && response['id'].present?
      Rails.logger.error "Media upload session failed: #{response.code} - #{response.body}"
      raise ArgumentError, extract_meta_error(response.body) || 'Failed to create upload session with Meta'
    end

    response['id']
  end

  def upload_file_bytes(session_id, file_data, content_type)
    response = HTTParty.post(
      "#{api_base_path}/#{WHATSAPP_API_VERSION}/#{session_id}",
      headers: {
        'Authorization' => "OAuth #{@whatsapp_channel.provider_config['api_key']}",
        'file_offset' => '0',
        'Content-Type' => content_type
      },
      body: file_data
    )

    unless response.success? && response['h'].present?
      Rails.logger.error "Media upload failed: #{response.code} - #{response.body}"
      raise ArgumentError, extract_meta_error(response.body) || 'Failed to upload media to Meta'
    end

    response['h']
  end

  def download_file(url)
    blob = find_active_storage_blob(url)
    return blob.download if blob

    response = HTTParty.get(url, follow_redirects: true, timeout: 30)
    response.success? ? response.body : nil
  rescue StandardError => e
    Rails.logger.error "Failed to download file from #{url}: #{e.message}"
    nil
  end

  def find_active_storage_blob(url)
    match = URI.parse(url).path.match(%r{/rails/active_storage/blobs/(?:redirect|proxy)/([^/]+)})
    return nil unless match

    ActiveStorage::Blob.find_signed(match[1])
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    nil
  end

  def validate_template_name!(name)
    raise ArgumentError, 'Template name is required' if name.blank?

    return if name.match?(/\A[a-z0-9_]+\z/)

    raise ArgumentError, 'Template name must contain only lowercase letters, numbers, and underscores'
  end

  def fetch_all_templates(url)
    response = HTTParty.get(url)
    return [] unless response.success?

    next_url = response.dig('paging', 'next')
    templates = response['data'] || []
    templates += fetch_all_templates(next_url) if next_url.present?
    templates
  end

  def business_account_path
    "#{api_base_path}/#{WHATSAPP_API_VERSION}/#{@whatsapp_channel.provider_config['business_account_id']}"
  end

  def api_headers
    { 'Authorization' => "Bearer #{@whatsapp_channel.provider_config['api_key']}", 'Content-Type' => 'application/json' }
  end

  def extract_meta_error(response_body)
    return nil if response_body.blank?

    data = JSON.parse(response_body)
    error = data['error'] || {}
    error['error_user_msg'] || error['message']
  rescue JSON::ParserError
    nil
  end

  def api_base_path
    ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end
end
