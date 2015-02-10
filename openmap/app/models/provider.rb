class Provider < ActiveRecord::Base

  has_many :provider_services
  has_many :provider_frns

  validates :name, presence: true

end
