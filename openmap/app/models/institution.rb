class Institution < ActiveRecord::Base

  belongs_to :cai_category

  validates :name, presence: true

  default_scope { select((column_names - ['geometry']).map { |column_name| "\"#{table_name}\".\"#{column_name}\""}) }

end
