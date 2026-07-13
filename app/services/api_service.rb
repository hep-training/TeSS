module ApiService
  def get_groups_from_query(query)
    getNewToken unless valid_token?
    response = HTTParty.post(
      TeSS::Config.feature['api_system_for_groups'] + '/Group/-/Query?includeArchivedAndDeleted=false',
      headers: {
        'Authorization' => "Bearer #{@@bearer_token}",
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: {
        operator: 'Equals',
        value: query,
        property: 'groupIdentifier'
      }.to_json
    )

    return [] unless response.success?
    response.parsed_response["data"] || []
  end

  def get_groups_by_username(username)
    getNewToken unless valid_token?
    response = HTTParty.get(
      TeSS::Config.feature['api_system_for_groups'] + "/Identity/#{username}/groups",
      headers: {
        "Authorization" => "Bearer #{@@bearer_token}",
        "Content-Type" => "application/json"
      }
    )

    return [] unless response.success?
    response.parsed_response["data"] || []
  end

  private

  def valid_token?
    return false unless defined?(@@bearer_token)
    response = HTTParty.get(
      TeSS::Config.feature['api_system_for_groups'] + "/Group/1",
      headers: {
        "Authorization" => "Bearer #{@@bearer_token}",
        "Content-Type" => "application/json"
      }
    )
    return response.code == 200
  end

  def getNewToken
    response = HTTParty.post(
        ENV["SSO_ISSUER"] + "/api-access/token",
        headers: {
            "Content-Type" => "application/x-www-form-urlencoded"
        },
        body: {
            grant_type: "client_credentials",
            client_id: ENV["SSO_API_CLIENT"],
            client_secret: ENV["SSO_API_SECRET"],
            audience: "authorization-service-api"
        }
    )

    @@bearer_token = response.parsed_response["access_token"]
  end
end