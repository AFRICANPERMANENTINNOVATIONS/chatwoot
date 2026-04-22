class TrialNotificationMailer < ApplicationMailer
  def trial_expiring(account:, user:, days_remaining:)
    @account = account
    @user = user
    @days_remaining = days_remaining
    @app_url = ENV.fetch('FRONTEND_URL', 'https://app.perfectcx.africa')
    @brand = GlobalConfigService.load('INSTALLATION_NAME', 'PerfectCX')

    subject = if days_remaining.zero?
                "#{@brand} — Votre essai gratuit expire aujourd'hui"
              else
                "#{@brand} — Votre essai gratuit expire dans #{days_remaining} jour#{'s' if days_remaining > 1}"
              end

    mail(to: user.email, subject: subject) do |format|
      format.html { render html: build_expiring_html.html_safe } # rubocop:disable Rails/OutputSafety
    end
  end

  def trial_expired(account:, user:)
    @account = account
    @user = user
    @app_url = ENV.fetch('FRONTEND_URL', 'https://app.perfectcx.africa')
    @brand = GlobalConfigService.load('INSTALLATION_NAME', 'PerfectCX')

    mail(
      to: user.email,
      subject: "#{@brand} — Votre essai gratuit est termine"
    ) do |format|
      format.html { render html: build_expired_html.html_safe } # rubocop:disable Rails/OutputSafety
    end
  end

  def subscription_activated(account:, user:, plan_label:, months:)
    @account = account
    @user = user
    @plan_label = plan_label
    @months = months
    @app_url = ENV.fetch('FRONTEND_URL', 'https://app.perfectcx.africa')
    @brand = GlobalConfigService.load('INSTALLATION_NAME', 'PerfectCX')

    mail(
      to: user.email,
      subject: "#{@brand} — Votre abonnement #{plan_label} est actif"
    ) do |format|
      format.html { render html: build_activated_html.html_safe } # rubocop:disable Rails/OutputSafety
    end
  end

  private

  def build_expiring_html
    <<~HTML
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 560px; margin: 0 auto; padding: 40px 20px;">
        <div style="text-align: center; margin-bottom: 32px;">
          <h1 style="color: #273444; font-size: 24px; margin: 0;">#{@brand}</h1>
        </div>
        <p style="color: #273444; font-size: 16px; line-height: 1.6;">
          Bonjour #{@user.name},
        </p>
        <p style="color: #6B7A8D; font-size: 15px; line-height: 1.6;">
          #{expiring_message}
        </p>
        <div style="background: #F8F5FF; border-radius: 12px; padding: 24px; margin: 24px 0; border-left: 4px solid #6F42B7;">
          <p style="color: #273444; font-size: 15px; margin: 0; font-weight: 600;">
            Passez au plan Pro pour continuer
          </p>
          <p style="color: #6B7A8D; font-size: 14px; margin: 8px 0 0;">
            A partir de 15 000 FCFA/mois pour 2 agents. Tarifs degressifs disponibles.
          </p>
        </div>
        <div style="text-align: center; margin: 32px 0;">
          <a href="#{@app_url}" style="background: #6F42B7; color: white; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 15px; display: inline-block;">
            Mettre a niveau mon compte
          </a>
        </div>
        <p style="color: #9DAAB8; font-size: 13px; line-height: 1.5;">
          Si vous avez des questions, repondez a cet email ou contactez-nous a info@permanentinnovations.africa
        </p>
        <hr style="border: none; border-top: 1px solid #E8E4F0; margin: 32px 0;" />
        <p style="color: #9DAAB8; font-size: 12px; text-align: center;">
          #{@brand} par Permanent Innovations Africa
        </p>
      </div>
    HTML
  end

  def build_expired_html
    <<~HTML
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 560px; margin: 0 auto; padding: 40px 20px;">
        <div style="text-align: center; margin-bottom: 32px;">
          <h1 style="color: #273444; font-size: 24px; margin: 0;">#{@brand}</h1>
        </div>
        <p style="color: #273444; font-size: 16px; line-height: 1.6;">
          Bonjour #{@user.name},
        </p>
        <p style="color: #6B7A8D; font-size: 15px; line-height: 1.6;">
          Votre essai gratuit de #{@brand} pour le compte <strong>#{@account.name}</strong> est termine.
          Votre compte a ete suspendu.
        </p>
        <div style="background: #FEF2F2; border-radius: 12px; padding: 24px; margin: 24px 0; border-left: 4px solid #DC2626;">
          <p style="color: #273444; font-size: 15px; margin: 0; font-weight: 600;">
            Votre compte est suspendu
          </p>
          <p style="color: #6B7A8D; font-size: 14px; margin: 8px 0 0;">
            Vos donnees sont conservees. Passez au plan Pro pour reactiver votre compte immediatement.
          </p>
        </div>
        <div style="text-align: center; margin: 32px 0;">
          <a href="#{@app_url}" style="background: #6F42B7; color: white; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 15px; display: inline-block;">
            Reactiver mon compte — 15 000 FCFA/mois
          </a>
        </div>
        <p style="color: #9DAAB8; font-size: 13px; line-height: 1.5;">
          Si vous avez des questions, contactez-nous a info@permanentinnovations.africa
        </p>
        <hr style="border: none; border-top: 1px solid #E8E4F0; margin: 32px 0;" />
        <p style="color: #9DAAB8; font-size: 12px; text-align: center;">
          #{@brand} par Permanent Innovations Africa
        </p>
      </div>
    HTML
  end

  def expiring_message
    if @days_remaining.zero?
      "Votre essai gratuit de #{@brand} pour le compte <strong>#{@account.name}</strong> expire <strong>aujourd'hui</strong>. " \
        'Apres expiration, votre compte sera suspendu et vous ne pourrez plus recevoir de messages.'
    else
      "Votre essai gratuit de #{@brand} pour le compte <strong>#{@account.name}</strong> expire dans " \
        "<strong>#{@days_remaining} jour#{'s' if @days_remaining > 1}</strong>. " \
        'Passez au plan Pro pour continuer a utiliser toutes les fonctionnalites.'
    end
  end

  def build_activated_html
    <<~HTML
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 560px; margin: 0 auto; padding: 40px 20px;">
        <div style="text-align: center; margin-bottom: 32px;">
          <h1 style="color: #273444; font-size: 24px; margin: 0;">#{@brand}</h1>
        </div>
        <p style="color: #273444; font-size: 16px; line-height: 1.6;">
          Bonjour #{@user.name},
        </p>
        <p style="color: #6B7A8D; font-size: 15px; line-height: 1.6;">
          Votre abonnement <strong>#{@plan_label}</strong> pour le compte <strong>#{@account.name}</strong> est maintenant actif.
        </p>
        <div style="background: #F0FDF4; border-radius: 12px; padding: 24px; margin: 24px 0; border-left: 4px solid #10B981;">
          <p style="color: #273444; font-size: 15px; margin: 0; font-weight: 600;">
            Abonnement active pour #{@months} mois
          </p>
          <p style="color: #6B7A8D; font-size: 14px; margin: 8px 0 0;">
            Vous avez acces a toutes les fonctionnalites de votre plan. Bonne utilisation !
          </p>
        </div>
        <div style="text-align: center; margin: 32px 0;">
          <a href="#{@app_url}" style="background: #6F42B7; color: white; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 15px; display: inline-block;">
            Acceder a mon compte
          </a>
        </div>
        <p style="color: #9DAAB8; font-size: 13px; line-height: 1.5;">
          Si vous avez des questions, contactez-nous a info@permanentinnovations.africa
        </p>
        <hr style="border: none; border-top: 1px solid #E8E4F0; margin: 32px 0;" />
        <p style="color: #9DAAB8; font-size: 12px; text-align: center;">
          #{@brand} par Permanent Innovations Africa
        </p>
      </div>
    HTML
  end
end
