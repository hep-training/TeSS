# Provides integration with an external API system for group management.
#
# Handles authentication via OAuth 2.0 bearer tokens and queries an external
# group service. Manages token lifecycle by validating and refreshing tokens
# as needed. Designed to abstract API communication details from consuming code.
module ApiService
  # Retrieves groups matching the given query identifier.
  #
  # Ensures a valid bearer token exists before making the request.
  # Queries the external API for groups matching the provided identifier.
  #
  # query:: The group identifier to search for.
  #
  # Returns:: An array of group objects (as hashes) with group data,
  # or an empty array if the query yields no results or the request fails.
  def get_groups_from_query(query)
    token = get_bearer_token
    response = HTTParty.post(
      TeSS::Config.feature['api_system_for_groups'] + '/Group/-/Query?includeArchivedAndDeleted=false',
      headers: {
        'Authorization' => "Bearer #{token}",
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: {
        operator: 'Equals',
        value: query,
        property: 'groupIdentifier'
      }.to_json
    )

    raise "fetch groups from API failed: #{response.code}" unless response.success?
    response.parsed_response["data"] || []
  end

  # Retrieves all groups associated with a given username.
  #
  # Ensures a valid bearer token exists before making the request.
  # Queries the external API for groups linked to the specified user identity.
  #
  # username:: The username whose groups are to be retrieved.
  #
  # Returns:: An array of group objects (as hashes) associated with the user,
  # or an empty array if no groups are found or the request fails.
  def get_groups_by_username(username)
    token = get_bearer_token
    response = HTTParty.get(
      TeSS::Config.feature['api_system_for_groups'] + "/Identity/#{username}/groups",
      headers: {
        "Authorization" => "Bearer #{token}",
        "Content-Type" => "application/json"
      }
    )

    raise "fetch user (#{username}) groups from API failed: #{response.code}" unless response.success?

    response.parsed_response["data"] || []
  end

  private

  # Retrieves a valid bearer token, using cached token if available and valid.
  #
  # Returns:: A valid OAuth 2.0 access token string.
  def get_bearer_token
    token = Rails.cache.fetch("api_service:bearer_token")
    token = fetch_new_token if token.blank?
    token
  end

  # Fetches a new bearer token from the SSO service and caches it.
  #
  # Uses OAuth 2.0 client credentials flow to obtain an access token
  # from the configured SSO issuer. Caches the token for 55 minutes
  # (assuming 1-hour token expiry to allow buffer for refresh).
  # Requires SSO_ISSUER, SSO_API_CLIENT, and SSO_API_SECRET environment variables.
  #
  # Returns:: The access token string.
  def fetch_new_token
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

    raise "SSO Token Request Failed: #{response.code}" unless response.success?

    token = response.parsed_response["access_token"]
    Rails.cache.fetch("api_service:bearer_token", expires_in: (response.parsed_response['expires_in'] - 60).seconds) { token }
    token
  end
end
