require 'test_helper'

class UserGroupCacheServiceTest < ActiveSupport::TestCase
  setup do
    @service = Object.new
    @service.extend(UserGroupCacheService)
    @service.instance_variable_set(:@user, users(:regular_user))
    @old_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear
  end

  teardown do
    ENV.delete('SSO_ISSUER')
    ENV.delete('SSO_API_CLIENT')
    ENV.delete('SSO_API_SECRET')
    Rails.cache = @old_cache_store
  end

  test 'get_cached_groups_of_user_or_fetch returns cached groups when present' do
    user = users(:regular_user)
    cache_key = @service.send(:cache_key, user)
    Rails.cache.write(cache_key, ['group-a', 'group-b'].to_json)

    assert_equal ['group-a', 'group-b'], @service.get_cached_groups_of_user_or_fetch(user)
  end

  test 'get_cached_groups_of_user_or_fetch fetches and caches groups when cache is empty' do
    user = users(:regular_user)
    payload = [{ 'groupIdentifier' => 'group-a' }, { 'groupIdentifier' => 'group-b' }]

    @service.stub(:get_groups_by_username, payload) do
      assert_equal ['group-a', 'group-b'], @service.get_cached_groups_of_user_or_fetch(user)
    end

    assert_equal ['group-a', 'group-b'], JSON.parse(Rails.cache.read(@service.send(:cache_key, user)))
  end

  test 'fetch_and_cache_groups fetches group identifiers and stores them in cache' do
    user = users(:regular_user)
    payload = [{ 'groupIdentifier' => 'group-a' }, { 'groupIdentifier' => 'group-b' }]

    @service.stub(:get_groups_by_username, payload) do
      assert_equal ['group-a', 'group-b'], @service.send(:fetch_and_cache_groups, user)
    end

    assert_equal ['group-a', 'group-b'], JSON.parse(Rails.cache.read(@service.send(:cache_key, user)))
  end

  test 'cache_key uses the user id' do
    user = users(:regular_user)
    assert_equal "user:#{user.id}:groups", @service.send(:cache_key, user)
  end
end
