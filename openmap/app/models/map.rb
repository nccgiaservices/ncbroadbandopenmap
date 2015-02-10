class Map < ActiveRecord::Base

  # the Map usually belongs to a state, but can optionaly have a geometry, for example, for a partial state map or a multi-state map.
  belongs_to :state

  has_many :map_styles

  validates :name, presence: true, uniqueness: true
  # We would normally validate a map to have either a state_id or a geometry, but because of the openmap setup and load
  # tasks, we have to allow the map to exist and be updated with those attributes later in the stepped process.

  default_scope { select((column_names - ['geometry']).map { |column_name| "\"#{table_name}\".\"#{column_name}\""}) }


  def centroid_lng_lat(projection=900913)
    if self.centroid.present?
      sql = "SELECT ST_X(centroid) AS lng, ST_Y(centroid) AS lat FROM map WHERE id = #{self.id}"
    else
      sql = "SELECT ST_X(ST_Transform(ST_Centroid(geometry),#{projection})) AS lng, ST_Y(ST_Transform(ST_Centroid(geometry),#{projection})) AS lat FROM state WHERE id = #{self.state_id}"
    end
    result = ActiveRecord::Base.connection.execute(sql)
    # result[0] hash looks like: {"lng"=>"-8808812.46429909", "lat"=>"4235597.37626491"}
    @centroid_lng_lat ||= [ result[0]["lng"], result[0]["lat"] ]
    @centroid_lng_lat
  end


end