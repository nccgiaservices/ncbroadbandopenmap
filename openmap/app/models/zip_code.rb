class ZipCode < ActiveRecord::Base

  validates :gid, :name, :geoid, presence: true

  # default_scope { select((column_names - ['geometry']).map { |column_name| "\"#{table_name}\".\"#{column_name}\""}) }


  scope :intersects_map, lambda { |map|
     joins("JOIN map ON map.id = #{map.id}")
    .where('ST_Intersects(zip_code.geometry, map.geometry)')
  }

end
