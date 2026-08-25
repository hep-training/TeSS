require 'test_helper'

class TessDevise::SessionsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end

  test 'destroy clears cached groups when the API group system is enabled' do
    user = users(:regular_user)
    sign_in user
    redis = Redis.new(url: TeSS::Config.redis_url)
    cache_key = "user:#{user.id}:groups"

    with_settings(feature: { 'api_system_for_groups' => true }) do
      redis.set(cache_key, ['group-1', 'group-2'].to_json)

      delete :destroy

      assert_nil redis.get(cache_key)
    end
  end

  test 'destroy does clear cached groups when the API group system is disabled' do
    user = users(:regular_user)
    sign_in user
    redis = Redis.new(url: TeSS::Config.redis_url)
    cache_key = "user:#{user.id}:groups"

    with_settings(feature: { 'api_system_for_groups' => false }) do
      redis.set(cache_key, ['group-1', 'group-2'].to_json)

      delete :destroy

      assert_nil redis.get(cache_key)
    end
  end
end
