require 'test_helper'

class ApiServiceTest < ActiveSupport::TestCase
  include ApiService

  setup do
    @api_base = 'https://groups.example.com'
    @token = 'abc123'
    @old_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    with_settings(feature: { 'api_system_for_groups' => @api_base }) do
      Rails.cache.delete('api_service:bearer_token')
    end
  end

  teardown do
    ENV.delete('SSO_ISSUER')
    ENV.delete('SSO_API_CLIENT')
    ENV.delete('SSO_API_SECRET')
    Rails.cache = @old_cache_store
  end

  test 'get_groups_from_query posts to group query endpoint and returns data' do
    response = OpenStruct.new(success?: true, code: 200, message: 'OK', parsed_response: { 'data' => [{ 'groupIdentifier' => 'g1', 'displayName' => 'Group One' }] })

    with_settings(feature: { 'api_system_for_groups' => @api_base }) do
      self.stub(:get_bearer_token, @token) do
        HTTParty.stub(:post, ->(_url, **_opts) { response }) do
          assert_equal [{ 'groupIdentifier' => 'g1', 'displayName' => 'Group One' }], get_groups_from_query('example')
        end
      end
    end
  end

  test 'get_groups_from_query raises when the API call fails' do
    response = OpenStruct.new(success?: false, code: 500, message: 'Server Error', parsed_response: {})

    with_settings(feature: { 'api_system_for_groups' => @api_base }) do
      self.stub(:get_bearer_token, @token) do
        HTTParty.stub(:post, ->(_url, **_opts) { response }) do
          error = assert_raises(RuntimeError) do
            get_groups_from_query('example')
          end
          assert_includes error.message, 'fetch groups from API failed'
        end
      end
    end
  end

  test 'get_groups_by_username gets user groups and returns data' do
    response = OpenStruct.new(success?: true, code: 200, message: 'OK', parsed_response: { 'data' => [{ 'groupIdentifier' => 'g1' }, { 'groupIdentifier' => 'g2' }] })

    with_settings(feature: { 'api_system_for_groups' => @api_base }) do
      self.stub(:get_bearer_token, @token) do
        HTTParty.stub(:get, ->(_url, **_opts) { response }) do
          assert_equal [{ 'groupIdentifier' => 'g1' }, { 'groupIdentifier' => 'g2' }], get_groups_by_username('alice')
        end
      end
    end
  end

  test 'get_groups_by_username raises when the API call fails' do
    response = OpenStruct.new(success?: false, code: 401, message: 'Unauthorized', parsed_response: {})

    with_settings(feature: { 'api_system_for_groups' => @api_base }) do
      self.stub(:get_bearer_token, @token) do
        HTTParty.stub(:get, ->(_url, **_opts) { response }) do
          error = assert_raises(RuntimeError) do
            get_groups_by_username('alice')
          end
          assert_includes error.message, 'fetch user (alice) groups from API failed'
        end
      end
    end
  end

  test 'get_bearer_token fetches a new token when cache is empty' do
    response = OpenStruct.new(success?: true, code: 200, message: 'OK', parsed_response: { 'access_token' => 'fresh-token', 'expires_in' => 3600 })

    with_settings(feature: { 'api_system_for_groups' => @api_base }) do
      ENV['SSO_ISSUER'] = 'https://sso.example.com'
      ENV['SSO_API_CLIENT'] = 'client'
      ENV['SSO_API_SECRET'] = 'secret'

      HTTParty.stub(:post, ->(_url, **_opts) { response }) do
        assert_equal 'fresh-token', get_bearer_token
        assert_equal 'fresh-token', Rails.cache.read('api_service:bearer_token')
      end
    end
  end

  test 'fetch_new_token raises when SSO token request fails' do
    response = OpenStruct.new(success?: false, code: 400, message: 'Bad Request', parsed_response: {})

    with_settings(feature: { 'api_system_for_groups' => @api_base }) do
      ENV['SSO_ISSUER'] = 'https://sso.example.com'
      ENV['SSO_API_CLIENT'] = 'client'
      ENV['SSO_API_SECRET'] = 'secret'

      HTTParty.stub(:post, ->(_url, **_opts) { response }) do
        error = assert_raises(RuntimeError) do
          send(:fetch_new_token)
        end
        assert_includes error.message, 'SSO Token Request Failed'
      end
    ensure
      ENV.delete('SSO_ISSUER')
      ENV.delete('SSO_API_CLIENT')
      ENV.delete('SSO_API_SECRET')
    end
  end
end
