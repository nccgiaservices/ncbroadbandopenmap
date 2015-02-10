class SpeedTier < ActiveRecord::Base

  # has_many :provider_services

  validates :code, presence: true, uniqueness: true

end
