# Provides integration with an external API system for group management.
#
# Handles authentication via OAuth 2.0 bearer tokens and queries an external
# group service. Manages token lifecycle by validating and refreshing tokens
# as needed. Designed to abstract API communication details from consuming code.
#
# Points of attention:: Uses class variables (@@bearer_token) for token caching,
# which is shared across all instances. Consider thread-safety implications
# in concurrent environments.
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

  # Validates whether the current bearer token is still active and authorized.
  #
  # Attempts a simple API request with the stored token to verify its validity.
  #
  # Returns:: True if the token is valid (API returns 200), false otherwise.
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

  # Fetches a new bearer token from the SSO service and stores it in the class variable.
  #
  # Uses OAuth 2.0 client credentials flow to obtain an access token
  # from the configured SSO issuer. Replaces any previously stored token.
  # Requires SSO_ISSUER, SSO_API_CLIENT, and SSO_API_SECRET environment variables.
  #
  # Returns:: The access token string, stored in @@bearer_token.
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
