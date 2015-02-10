class ServedArea < ActiveRecord::Base

  belongs_to :technology

  validates :technology, presence: true, uniqueness: true

  default_scope { select((column_names - ['geometry']).map { |column_name| "\"#{table_name}\".\"#{column_name}\""}) }

end
