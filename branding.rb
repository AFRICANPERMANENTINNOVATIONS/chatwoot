#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open-uri'
require 'fileutils'
require 'json'

# ULTIMATE Branding Update Script
# Handles EVERYTHING: logos, PWA icons, manifest.json, bot avatars, i18n text, etc.
# Usage: bundle exec rails runner scripts/update-branding-ultimate.rb

puts "🎨 PerfectCX ULTIMATE Branding Update Script"
puts "=============================================="
puts ""

# ============================================
# CONFIGURATION
# ============================================

BRANDING_CONFIG = {
  'INSTALLATION_NAME' => 'PerfectCX',
  'BRAND_NAME' => 'PerfectCX',
  'BRAND_URL' => 'https://permanentinnovations.africa/perfectcx',
  'WIDGET_BRAND_URL' => 'https://permanentinnovations.africa/perfectcx',
  'LOGO' => '/brand-assets/logo.svg',
  'LOGO_DARK' => '/brand-assets/logo_dark.svg',
  'LOGO_THUMBNAIL' => '/brand-assets/logo_thumbnail.svg',
  'TERMS_URL' => 'https://permanentinnovations.africa/perfectcx/terms',
  'PRIVACY_URL' => 'https://permanentinnovations.africa/perfectcx/privacy'
}.freeze

WIDGET_COLOR = '#2781F6'

LOGO_URLS = {
  'logo.svg' => 'https://permanentinnovations.africa/perfectcx/brand-assets/logo.svg',
  'logo_dark.svg' => 'https://permanentinnovations.africa/perfectcx/brand-assets/logo_dark.svg',
  'logo_thumbnail.svg' => 'https://permanentinnovations.africa/perfectcx/brand-assets/logo_thumbnail.svg'
}.freeze

# PWA Icon source
PWA_ICON_SOURCE_URL = 'https://permanentinnovations.africa/perfectcx/apple-icon.png'

# Bot avatar (shows in conversations when bot replies)
# Set to nil to skip updating bot avatar
BOT_AVATAR_URL = nil  # Not updating - keeping default

# Widget bubble logo (small logo in chat widget)
# Set to nil to skip updating widget bubble logo
WIDGET_BUBBLE_LOGO_URL = nil  # Not updating - keeping default

# Open Graph image for social sharing (recommended: 1200x630px)
OG_IMAGE_URL = ''

# Directories
BRAND_ASSETS_DIR = Rails.root.join('public', 'brand-assets')
PUBLIC_DIR = Rails.root.join('public')
DASHBOARD_IMAGES_DIR = Rails.root.join('app', 'javascript', 'dashboard', 'assets', 'images')

# PWA Icon sizes (includes missing ones)
PWA_ICON_SIZES = {
  # Android icons
  'android-icon-36x36.png' => 36,
  'android-icon-48x48.png' => 48,
  'android-icon-72x72.png' => 72,
  'android-icon-96x96.png' => 96,
  'android-icon-144x144.png' => 144,
  'android-icon-192x192.png' => 192,

  # Apple icons
  'apple-icon-57x57.png' => 57,
  'apple-icon-60x60.png' => 60,
  'apple-icon-72x72.png' => 72,
  'apple-icon-76x76.png' => 76,
  'apple-icon-114x114.png' => 114,
  'apple-icon-120x120.png' => 120,
  'apple-icon-144x144.png' => 144,
  'apple-icon-152x152.png' => 152,
  'apple-icon-180x180.png' => 180,
  'apple-icon.png' => 180,
  'apple-icon-precomposed.png' => 180,
  'apple-touch-icon.png' => 180,  # Added
  'apple-touch-icon-precomposed.png' => 180,  # Added

  # Microsoft icons
  'ms-icon-70x70.png' => 70,
  'ms-icon-144x144.png' => 144,
  'ms-icon-150x150.png' => 150,
  'ms-icon-310x310.png' => 310,

  # Favicons
  'favicon-16x16.png' => 16,
  'favicon-32x32.png' => 32,
  'favicon-96x96.png' => 96,
  'favicon-512x512.png' => 512,
  'favicon-badge-16x16.png' => 16,  # Added (for notifications)
  'favicon-badge-32x32.png' => 32,  # Added
  'favicon-badge-96x96.png' => 96,  # Added
  'favicon.ico' => 32
}.freeze

# Helper functions
def download_file(url, destination)
  return false if url.nil? || url.empty?

  puts "  📥 Downloading: #{url}"
  URI.open(url, 'User-Agent' => 'PerfectCX-Branding') do |remote|
    File.open(destination, 'wb') { |f| f.write(remote.read) }
  end
  puts "  ✓ Saved: #{File.basename(destination)} (#{File.size(destination)} bytes)"
  true
rescue StandardError => e
  puts "  ❌ Failed: #{e.message}"
  false
end

def backup_file(path)
  return unless File.exist?(path)

  backup = "#{path}.backup.#{Time.now.to_i}"
  FileUtils.cp(path, backup)
  puts "  💾 Backed up: #{File.basename(backup)}"
end

def check_imagemagick
  system('which convert > /dev/null 2>&1')
end

def generate_icon(source, dest, size)
  return false unless check_imagemagick

  if File.basename(dest) == 'favicon.ico'
    system("convert #{source} -resize #{size}x#{size} #{dest}")
  else
    system("convert #{source} -resize #{size}x#{size} -background none -gravity center -extent #{size}x#{size} #{dest}")
  end

  File.exist?(dest)
rescue StandardError
  false
end

# Main execution
puts "Step 1: Download brand logos"
puts "=" * 60

FileUtils.mkdir_p(BRAND_ASSETS_DIR)
download_count = 0

LOGO_URLS.each do |filename, url|
  next if url.nil? || url.empty?

  dest = BRAND_ASSETS_DIR.join(filename)
  backup_file(dest)
  download_count += 1 if download_file(url, dest)
end

puts "✅ Downloaded #{download_count}/#{LOGO_URLS.size} logos\n\n"

# Download bot avatar
puts "Step 2: Download bot avatar"
puts "=" * 60

unless BOT_AVATAR_URL.nil? || BOT_AVATAR_URL.empty?
  FileUtils.mkdir_p(DASHBOARD_IMAGES_DIR)
  FileUtils.mkdir_p(PUBLIC_DIR.join('assets', 'images'))

  bot_dest1 = DASHBOARD_IMAGES_DIR.join('chatwoot_bot.png')
  bot_dest2 = PUBLIC_DIR.join('assets', 'images', 'chatwoot_bot.png')

  [bot_dest1, bot_dest2].each { |dest| backup_file(dest) }

  if download_file(BOT_AVATAR_URL, bot_dest1)
    FileUtils.cp(bot_dest1, bot_dest2)
    puts "✅ Bot avatar updated in 2 locations"
  end
else
  puts "⏭️  Skipping (BOT_AVATAR_URL not set)"
end

puts ""

# Download widget bubble logo
puts "Step 3: Download widget bubble logo"
puts "=" * 60

unless WIDGET_BUBBLE_LOGO_URL.nil? || WIDGET_BUBBLE_LOGO_URL.empty?
  bubble_dest = DASHBOARD_IMAGES_DIR.join('bubble-logo.svg')
  backup_file(bubble_dest)

  if download_file(WIDGET_BUBBLE_LOGO_URL, bubble_dest)
    puts "✅ Widget bubble logo updated"
  end
else
  puts "⏭️  Skipping (WIDGET_BUBBLE_LOGO_URL not set)"
end

puts ""

# Generate PWA icons
puts "Step 4: Generate PWA icons"
puts "=" * 60

if PWA_ICON_SOURCE_URL && !PWA_ICON_SOURCE_URL.empty? && check_imagemagick
  source = "/tmp/pwa-source-#{Time.now.to_i}.png"

  if download_file(PWA_ICON_SOURCE_URL, source)
    generated = 0

    PWA_ICON_SIZES.each do |filename, size|
      dest = PUBLIC_DIR.join(filename)
      backup_file(dest) if File.exist?(dest)

      if generate_icon(source, dest, size)
        generated += 1
        puts "  ✓ #{filename}"
      end
    end

    File.delete(source) if File.exist?(source)
    puts "\n✅ Generated #{generated}/#{PWA_ICON_SIZES.size} icons"
  end
else
  puts "⏭️  Skipping (ImageMagick not found or PWA_ICON_SOURCE_URL not set)"
end

puts ""

# Update manifest.json
puts "Step 5: Update manifest.json"
puts "=" * 60

manifest_path = PUBLIC_DIR.join('manifest.json')
if File.exist?(manifest_path)
  backup_file(manifest_path)

  manifest = JSON.parse(File.read(manifest_path))
  manifest['name'] = BRANDING_CONFIG['BRAND_NAME']
  manifest['short_name'] = BRANDING_CONFIG['BRAND_NAME']
  manifest['theme_color'] = WIDGET_COLOR
  manifest['background_color'] = WIDGET_COLOR

  File.write(manifest_path, JSON.pretty_generate(manifest))
  puts "✅ manifest.json updated:"
  puts "  • name: #{manifest['name']}"
  puts "  • short_name: #{manifest['short_name']}"
  puts "  • theme_color: #{manifest['theme_color']}"
else
  puts "⚠️  manifest.json not found"
end

puts ""

# Update installation configs
puts "Step 6: Update installation configs"
puts "=" * 60

BRANDING_CONFIG.each do |name, value|
  config = InstallationConfig.find_or_create_by(name: name)
  old = config.value
  config.update!(value: value)
  puts "  ✓ #{name}: #{old != value ? "#{old} → #{value}" : value}"
end

# Add OG image config if provided
unless OG_IMAGE_URL.nil? || OG_IMAGE_URL.empty?
  InstallationConfig.find_or_create_by(name: 'OG_IMAGE_CDN_URL').update!(value: OG_IMAGE_URL)
  puts "  ✓ OG_IMAGE_CDN_URL: #{OG_IMAGE_URL}"
end

puts "\n✅ Installation configs updated"
puts ""

# Update widget colors
puts "Step 7: Update widget colors"
puts "=" * 60

if WIDGET_COLOR
  widgets = Channel::WebWidget.all
  if widgets.any?
    widgets.each do |w|
      w.update!(widget_color: WIDGET_COLOR)
      puts "  ✓ Inbox ##{w.inbox.id} (#{w.inbox.name}): → #{WIDGET_COLOR}"
    end
    puts "\n✅ Updated #{widgets.count} widget(s)"
  else
    puts "  ℹ️  No widgets found"
  end
end

puts ""

# Clear cache
puts "Step 8: Clear cache"
puts "=" * 60
Rails.cache.clear
puts "✅ Cache cleared"

puts ""
puts "=" * 60
puts "🎉 ULTIMATE branding update complete!"
puts "=" * 60
puts ""

puts "📋 Summary:"
puts "  ✓ Brand logos (#{LOGO_URLS.size} files)"
puts "  ✓ Bot avatar (2 locations)"
puts "  ✓ Widget bubble logo"
puts "  ✓ PWA icons (#{PWA_ICON_SIZES.size} sizes)"
puts "  ✓ manifest.json"
puts "  ✓ Installation configs"
puts "  ✓ Widget colors"

puts ""
puts "⚠️  Manual steps remaining:"
puts "  1. Update English i18n files (see checklist below)"
puts "  2. Update .env for email settings"
puts "  3. Restart Rails server"
puts "  4. Hard refresh browser (Ctrl+F5)"

puts ""
puts "📝 I18n files to manually update:"
puts "  • app/javascript/dashboard/i18n/locale/en/login.json"
puts "  • app/javascript/dashboard/i18n/locale/en/settings.json"
puts "  • app/javascript/dashboard/i18n/locale/en/inboxMgmt.json"
puts "  • app/javascript/dashboard/i18n/locale/en/yearInReview.json"

puts ""
