require 'test_helper'

class ApplicationPolicyTest < ActiveSupport::TestCase
  setup do
    @space = spaces(:plants)
    @space.is_private = true
    @space.api_groups = %w[group-a group-b]
    @space.save!(validate: false)
  end

  test 'shown? returns true for records without an associated space' do
    policy = ApplicationPolicy.new(Pundit::CurrentContext.new(users(:regular_user), nil), User.new)
    assert policy.shown?
  end

  test 'shown? returns true for public spaces regardless of user' do
    @space.is_private = false
    @space.save!(validate: false)

    policy = ApplicationPolicy.new(Pundit::CurrentContext.new(users(:regular_user), @space), @space)
    assert policy.shown?
  end

  test 'shown? returns false for unauthenticated users on private space' do
    policy = ApplicationPolicy.new(Pundit::CurrentContext.new(nil, @space), @space)
    refute policy.shown?
  end

  test 'shown? returns true for admin on private space' do
    policy = ApplicationPolicy.new(Pundit::CurrentContext.new(users(:admin), @space), @space)
    assert policy.shown?
  end

  test 'shown? returns true for user in matching API group' do
    user = users(:regular_user)
    with_settings(feature: { 'api_system_for_groups' => true }) do
      user.stub(:is_admin?, false) do
        policy = ApplicationPolicy.new(Pundit::CurrentContext.new(user, @space), @space)
        policy.stub(:get_cached_groups_of_user_or_fetch, ['group-a']) do
          assert policy.shown?
        end
      end
    end
  end

  test 'shown? returns false when user lacks matching space group' do
    user = users(:regular_user)
    with_settings(feature: { 'api_system_for_groups' => true }) do
      user.stub(:is_admin?, false) do
        policy = ApplicationPolicy.new(Pundit::CurrentContext.new(user, @space), @space)
        policy.stub(:get_cached_groups_of_user_or_fetch, ['group-c']) do
          refute policy.shown?
        end
      end
    end
  end

  test 'shown? falls back to regular groups when API system is disabled' do
    user = users(:regular_user)
    group = groups(:one)
    @space.groups = [group]

    with_settings(feature: { 'api_system_for_groups' => false }) do
      user.stub(:groups, Group.where(id: group.id)) do
        policy = ApplicationPolicy.new(Pundit::CurrentContext.new(user, @space), @space)
        assert policy.shown?
      end
    end
  end
end
