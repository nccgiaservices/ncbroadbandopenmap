# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).


# create admin for DEV else topsailtech for the system account
u = UserProfile.create!( username: (Rails.env.development? ? 'admin' : 'topsailtech'), name: 'Topsail Technologies', email: 'info@topsailtech.com')

# UserProfile.current_user = u

# if not dev, reset the topsailtech password thru the console
if Rails.env.development?
  u.email = 'admin'             # easy dev login
  u.password = 'admin'          # deal with devise setting password for me on UserProfile.create
  u.save!(validate: false)
end


# We need a Postgres view and since it won't be part of schema.rb let's put it here
#
# Create view to encapsulate the provider served area data and not have to worry about geometries being fetched into our model
#
puts "Creating served provider provider_service view..."

connection = ActiveRecord::Base.connection
connection.execute("DROP VIEW IF EXISTS provider_service_view")

connection.execute("CREATE VIEW provider_service_view AS
  SELECT
    provider_service.id                   AS id,
    provider.id                           AS provider_id,
    provider.name                         AS provider_name,
    provider.name_dba                     AS provider_name_dba,
    provider.name_short                   AS provider_name_short,
    provider.website                      AS provider_website,
    technology.name                       AS technology_name,
    technology.description                AS technology_description,
    map_style.color                       AS technology_color,
    speed_up.code                         AS speed_up_code,
    speed_down.code                       AS speed_down_code,
    speed_up.description                  AS speed_up_description,
    speed_down.description                AS speed_down_description,
    (residential='f' and commercial='t')  AS non_res_only,
    provider_service.residential          AS residential,
    provider_service.commercial           AS commercial,
    provider_service.geometry             AS geometry
  FROM provider_service
  JOIN provider ON provider.id = provider_service.provider_id
  JOIN technology ON technology.id = provider_service.technology_id
  JOIN speed_tier speed_up ON speed_up.id = provider_service.speed_up_id
  JOIN speed_tier speed_down ON speed_down.id = provider_service.speed_down_id
  LEFT JOIN map_style ON map_style.layerable_type = 'Technology' AND map_style.layerable_id = technology.id")

