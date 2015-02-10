#
# Reads file config/config.yaml
#  Settings come from top level elements according to the Rails.env.
#  Fallback is 'default'.
#
# Example config/config.yaml
#   default:
#     a: 1
#     b: 2
#   development:
#     b: 3
#     mail_server:
#       ip: 'smtp.somewhere'
#
# Run in development:
#     Settings[:a]   # 1
#     Settings[:b]   # 3
#     Settings[:mail_server][:ip]   # 'smtp.somewhere'

class Settings

  def self.[](key)
    self.data[key]
  end

  #private
  def self.data
    @@data ||= self.load_data.freeze
    @@data
  end

  def self.load_data
    Rails.logger.debug "Settings: re-reading config files"
    all_settings = YAML.load_file("#{Rails.root}/config/config.yml").with_indifferent_access
    (all_settings[:default] || {}.with_indifferent_access).deep_merge(all_settings[Rails.env] || {})
  end

end