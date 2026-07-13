# Caches user group memberships in Redis to reduce API calls to the external group service.
#
# Extends ApiService to provide transparent caching: group data is fetched once per user,
# stored in Redis with a one-hour TTL, and reused on subsequent requests.
# Designed to improve performance in high-traffic scenarios by reducing load on the
# external API system.
module UserGroupCacheService
  include ApiService

  @@redis = Redis.new(url: TeSS::Config.redis_url)

  # Retrieves groups for a user, checking Redis cache first before making an API call.
  #
  # Attempts to fetch the user's groups from the Redis cache. If not cached,
  # fetches the groups from the external API and caches them with a one-hour TTL.
  #
  # user:: The user object for which groups are to be retrieved.
  #
  # Returns:: An array of group identifier strings.
  def get_cached_groups_of_user_or_fetch(user)
    cached_groups ||= @@redis.get(cache_key(user))
    if cached_groups.nil?
      cached_groups = fetch_and_cache_groups(user)
    else
      cached_groups = JSON.parse(cached_groups)
    end
    cached_groups
  end

  private

  # Fetches groups from the API for the given user and caches the result in Redis.
  #
  # Calls the external API via ApiService#get_groups_by_username and extracts
  # group identifiers. Stores the result in Redis with a one-hour expiration.
  #
  # user:: The user object whose groups are to be fetched and cached.
  #
  # Returns:: An array of group identifier strings.
  def fetch_and_cache_groups(user)
    groups = get_groups_by_username(@user.username).map { |obj| obj['groupIdentifier'] }
    @@redis.setex(cache_key(user), 1.hour.to_i, groups.to_json)
    groups
  end

  # Generates a Redis cache key for the given user's groups.
  #
  # user:: The user object for which to generate the cache key.
  #
  # Returns:: A string cache key in the format "user:{user_id}:groups".
  def cache_key(user)
    "user:#{user.id}:groups"
  end
end
