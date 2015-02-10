class District < ActiveRecord::Base

  belongs_to :state

  validates :gid, :name, :geoid, :state, presence: true

  default_scope { select((column_names - ['geometry']).map { |column_name| "\"#{table_name}\".\"#{column_name}\""}) }
  # because we set select on a default scope, the class .count method will try to count all columns
  # so in using District.count (or other default_scoped classes) you must explicitly call .count(:all)

  scope :intersects_map, lambda { |map|
     joins("JOIN map ON map.id = #{map.id}")
    .where('ST_Intersects(district.geometry, map.geometry)')
  }

end
