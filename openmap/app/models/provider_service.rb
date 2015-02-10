class ProviderService < ActiveRecord::Base

  belongs_to :provider
  belongs_to :technology
  belongs_to :speed_up, class_name: "SpeedTier"
  belongs_to :speed_down, class_name: "SpeedTier"

  validates :provider, :technology, :speed_up, :speed_down, presence: true

  # this prevents the geometry column blob data from being fetched
  default_scope { select((column_names - ['geometry']).map { |column_name| "\"#{table_name}\".\"#{column_name}\""}) }

end
