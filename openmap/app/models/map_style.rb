class MapStyle < ActiveRecord::Base

  belongs_to :map
  belongs_to :layerable, polymorphic: true

  validates :map, presence: true

end
