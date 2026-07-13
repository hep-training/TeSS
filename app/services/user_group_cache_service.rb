module UserGroupCacheService
  include ApiService

  @@redis = Redis.new(url: TeSS::Config.redis_url)

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

  def fetch_and_cache_groups(user)
    groups = get_groups_by_username(@user.username).map { |obj| obj['groupIdentifier'] }
    @@redis.setex(cache_key(user), 1.hour.to_i, groups.to_json)
    groups
  end

  def cache_key(user)
    "user:#{user.id}:groups"
  end
end
