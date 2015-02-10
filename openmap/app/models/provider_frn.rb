class ProviderFrn < ActiveRecord::Base

  belongs_to :provider

  validates :provider, :frn, presence: true

end
