class ProviderServiceView < ActiveRecord::Base

  self.table_name = "provider_service_view"

  default_scope { select((column_names - ['geometry']).map { |column_name| "\"#{table_name}\".\"#{column_name}\""}) }

  # default layers are in WGS84 (EPSG:4326) projection
  # Google maps are in popular Web Mercator (EPSG:3857 aka EPSG:900913)
  # need to transform unless lat/lng are in Web Mercator

  scope :instersects_lng_lat, lambda { |lng, lat, epsg=0|
    if epsg == 4269
      where('ST_Intersects(provider_service_view.geometry, ST_SetSRID(ST_MakePoint(?,?),4269))', lng, lat)
    else
      where('ST_Intersects(provider_service_view.geometry, ST_Transform(ST_SetSRID(ST_MakePoint(?,?), 900913), 4269))', lng, lat)
    end
  }

  scope :instersects_envelope, lambda { |left,bottom,top,right|
    where('ST_Intersects(provider_service_view.geometry,ST_MakeEnvelope(?, ?, ?, ?, 4269))', left, bottom, right, top)
  }

  scope :instersects_district, lambda { |district|
     joins("JOIN district ON district.id = " + District.sanitize(district))
    .where('ST_Intersects(provider_service_view.geometry,district.geometry)')
  }

  scope :instersects_county, lambda { |county_name|
     joins("JOIN \"county\" ON lower(\"name\") = #{self.sanitize(county_name.downcase)}")
    .where('ST_Intersects(provider_service_view.geometry,"county".geometry)')
  }

  scope :instersects_zip, lambda { |zip|
     joins("JOIN \"zip_code\" ON \"name\" = #{self.sanitize(zip)}")
    .where('ST_Intersects(provider_service_view.geometry,"zip_code".geometry)')
  }

  scope :key_data, lambda {
    # not really using this any more - instead apply the default scope above to omit the geometry -- leaving around for reference
    select('provider_id, provider_name, provider_name_dba, provider_name_short, provider_website,
            technology_name, non_res_only, residential, speed_down_code, speed_up_code, speed_down_description, speed_up_description')
    # OLD values
    # select('provider_service_view.fid,
    #         served_providers_view.provider_name,     -- now Provider.name  => provider_name
    #         served_providers_view.dba_name,          -- now Provider.name_dba => provider_name_dba
    #         served_providers_view.short_name,        -- now Provider.name_short => provider_name_short
    #         trans_tech,    =>  10,20,40,41           -- now TechType.code (not using this in the view, they are collapsed into referenced Technology)
    #         layer_name,    => 'Cable','DSL'          -- now Technology.name => technology_name
    #         description,                             -- now Technology.description => technology_description
    #         non_res_only,  => 'N' or 'Y'             -- now provider_service.residential
    #         max_down_num,                            -- now speed_down.code => speed_down_code
    #         max_up_num,                              -- now speed_up.code => speed_up_code
    #         website,                                 -- now provider.website => provider_website
    #         tech_type,    ----------- what us this now
    #         max_up_description,                      -- speed_up.description => speed_up_description
    #         max_down_description                     -- speed_down.description => speed_down_description
  }

  scope :ordered, lambda {
    # this order allows the view to collapse the providers with the same name+technology, with the highest max_speed down record being the one used)
    # TODO: need to get the non-res only indicator into the view/select output (calculated value)
    order('non_res_only, technology_name, provider_name_dba, speed_down_code DESC')
  }


  def name
    self.provider_name
  end

  def short_name
    self.read_attribute(:provider_name_short).present? ? self.read_attribute(:provider_name_short) : self.provider_name_dba
  end

end