# A Group is a collection of users, joined via GroupMembership.
#
# Groups are primarily used to control access to private Space objects: a
# private space is only accessible to users belonging to one of the space's
# associated groups (see ApplicationPolicy#shown?).
class Group < ApplicationRecord
end