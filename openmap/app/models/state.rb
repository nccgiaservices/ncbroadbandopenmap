class State < ActiveRecord::Base

  has_many :counties
  has_many :districts

  validates :gid, :name, :statefp, :geoid, presence: true

  default_scope { select((column_names - ['geometry']).map { |column_name| "\"#{table_name}\".\"#{column_name}\""}) }

end