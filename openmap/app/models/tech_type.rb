class TechType < ActiveRecord::Base

  belongs_to :technology

  validates :code, presence: true, uniqueness: true

end
