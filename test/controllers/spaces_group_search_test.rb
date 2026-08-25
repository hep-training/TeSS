require 'test_helper'

class SpacesGroupSearchTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @space = spaces(:plants)
    @admin = users(:admin)
    @owner = @space.user
    @controller = SpacesController.new
  end

  test 'search_groups authorizes admin and returns transformed groups' do
    sign_in @admin
    space = @space
    query = 'lab'

    with_settings(feature: { 'api_system_for_groups' => true }) do
      @controller.stub(:get_groups_from_query, [{ 'groupIdentifier' => 'group-1', 'displayName' => 'Lab One' }, { 'groupIdentifier' => 'group-2', 'displayName' => 'Lab Two' }]) do
        get :search_groups, params: { q: query }
      end
    end

    assert_response :success
    assert_equal [{ 'id' => 'group-1', 'title' => 'Lab One' }, { 'id' => 'group-2', 'title' => 'Lab Two' }], JSON.parse(response.body)
  end

  test 'search_groups_with_id denies unauthorized users with error JSON' do
    sign_in users(:regular_user)
    get :search_groups_with_id, params: { id: @space.id, q: 'lab' }

    assert_response :success
    assert_equal({ 'error' => 'user does not have permissions do search groups of this space.' }, JSON.parse(response.body))
  end

  test 'search_groups_with_id authorizes permitted user and returns transformed groups' do
    sign_in @owner

    with_settings(feature: { 'api_system_for_groups' => true }) do
      @controller.stub(:get_groups_from_query, [{ 'groupIdentifier' => 'group-1', 'displayName' => 'Lab One' }]) do
        get :search_groups_with_id, params: { id: @space.id, q: 'lab' }
      end
    end

    assert_response :success
    assert_equal [{ 'id' => 'group-1', 'title' => 'Lab One' }], JSON.parse(response.body)
  end

  test 'transform_groups converts raw group hashes to expected payload' do
    payload = @controller.send(:transform_groups, [
      { 'groupIdentifier' => 'g1', 'displayName' => 'Group 1' },
      { 'groupIdentifier' => 'g2', 'displayName' => 'Group 2' }
    ])

    assert_equal [{ id: 'g1', title: 'Group 1' }, { id: 'g2', title: 'Group 2' }], payload
  end
end
