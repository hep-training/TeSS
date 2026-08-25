require 'test_helper'

class SpacePolicyTest < ActiveSupport::TestCase
  setup do
    @space = spaces(:plants)
  end

  test 'search_groups? allows owner/admin and denies others' do
    owner_policy = SpacePolicy.new(Pundit::CurrentContext.new(@space.user, nil), @space)
    admin_policy = SpacePolicy.new(Pundit::CurrentContext.new(users(:admin), nil), @space)
    regular_policy = SpacePolicy.new(Pundit::CurrentContext.new(users(:regular_user), nil), @space)

    assert owner_policy.search_groups?
    assert admin_policy.search_groups?
    refute regular_policy.search_groups?
  end
end
