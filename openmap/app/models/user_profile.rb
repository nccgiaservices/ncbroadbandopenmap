class UserProfile < ActiveRecord::Base

  devise :database_authenticatable
  devise :registerable, :validatable, :recoverable      # user self registration, email validator, forgot my password
  devise :trackable, :lockable                          # number of logins, last login, etc. login attempt strike out lockout
  devise :rememberable, :timeoutable                    # rememberable preserves user credentials in cookie across browser restarts, timeout is just what it means
                                                        # it's important to note that the timout period will trump the rememberable period
  # NOT USED YET :confirmable, :omniauthable


  # allow login via username (later for ldap) or email (for outsiders)
  attr_accessor :login

  validates :username, :presence => true
  validates :name, :presence => true

  # Devise validatable requires a password
  before_validation(on: :create) do
    self.password = Devise.token_generator.generate(UserProfile, :reset_password_token)[1]
                    # Devise.friendly_token[0, 20]
  end

  #
  # Devise
  #
  public
  def active_for_authentication?
    self.active? ? super : false
  end

  def email_required?
    true
  end

  # Devise allow login via username or email
  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    else
      where(conditions).first
    end
  end
end