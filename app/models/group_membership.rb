# GroupMembership is the join model between User and Group.
#
# Beyond simple membership, it also tracks whether the user is an *owner*
# of the group (see the +owner+ attribute, managed for example by
# GroupsController#sync_owners), which grants additional permissions such
# as editing or destroying the group (see GroupPolicy#owner?).
# Used only when Group API System is enabled.
class GroupMembership < ApplicationRecord
  unless TeSS::Config.feature['api_system_for_groups']
    self.primary_key = [:group_id, :user_id]   # Composite primary key: a user can only have a single membership per group
    belongs_to :user
    belongs_to :group
  end
end