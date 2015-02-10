class Technology < ActiveRecord::Base

  has_many :provider_services
  has_many :served_areas
  has_many :tech_types

  validates :name, presence: true, uniqueness: true

  default_scope { select((column_names - ['geometry']).map { |column_name| "\"#{table_name}\".\"#{column_name}\""}) }

end
