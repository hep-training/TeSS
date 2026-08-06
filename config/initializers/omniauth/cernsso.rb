# OpenID Connect configuration for CERN (Switzerland)
unless Rails.application.config.secrets.dig(:oidc3, :client_id).blank?
  Devise.omniauth :oidc3, {
    name: :oidc3,
    issuer: Rails.application.config.secrets.oidc3[:issuer],
    strategy_class: OmniAuth::Strategies::OpenIDConnect,
    scope: [:openid, :email, :profile],
    response_type: 'code',
    discovery: true,
    send_nonce: true,
    client_signing_alg: :RS256,
    client_options: {
      redirect_uri: Rails.application.config.secrets.oidc3[:redirect_uri],
      identifier: Rails.application.config.secrets.oidc3[:client_id],
      secret: Rails.application.config.secrets.oidc3[:secret]
    }
  }
end
