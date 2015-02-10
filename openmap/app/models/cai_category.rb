class CaiCategory < ActiveRecord::Base

  has_many :institutions

  validates :code, :name, presence: true, uniqueness: true

end