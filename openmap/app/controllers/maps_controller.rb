class MapsController < ApplicationController

  layout 'map', :only => [:index, :show]

  def index
    @map = Map.first
    set_variables_for_view
    render :show
  end

  def show
    @map = Map.find(params[:id])
    set_variables_for_view
  end

  # examples:
  # http://localhost:3000/broadband_map/providers.json?by=point&lat=4299571.2586533&lng=-8783675.3736585
  # http://localhost:3000/broadband_map/providers.json?by=bounds&left=-8783825.541457623&bottom=4299385.6590061&right=-8783525.205859384&top=4299756.858300543
  # Wilson, NC
  # http://localhost:3000/broadband_map/providers.json?by=bounds&left=-8687389.101436399&bottom=4255534.469585973&right=-8667960.154488582&top=4275038.5314479135
  # http://localhost:3000/broadband_map/providers.json?by=bounds&left=-78.04014410000002&bottom=35.67165&right=-77.86561089999998&top=35.8138571
  # http://localhost:3000/broadband_map/providers.json?by=district&legislation=NC_House&district=10
  # http://localhost:3000/broadband_map/providers.json?by=county&name=Durham
  # http://localhost:3000/broadband_map/providers.json?by=zip&code=27701&mobile=1

  def providers
    rel = case params[:by]
    when "point"
      ProviderServiceView.instersects_lng_lat(params[:lng], params[:lat])
    when "bounds"
      ProviderServiceView.instersects_envelope(params[:left], params[:bottom], params[:top], params[:right])
    when "district"
      ProviderServiceView.instersects_district(params[:district])
    when "county"
      ProviderServiceView.instersects_county(params[:name])
    when "zip"
      ProviderServiceView.instersects_zip(params[:code])
    else
      ProviderServiceView.where('1=2')
    end

    # uniq to get only the max MaxDownNum value if multiples exist for the same TRANSTECH
    # this relies on the ordered() scope returning the results in DESCending MaxDownNum order
    # AND that uniq will always select the first occurrence from the set - probably should revisit this later

    # debugging helpfuls
    # @mobile = params[:mobile].present?
    # @sql = rel.ordered.to_sql if params[:debug].present?
    # Rails.logger.debug rel.ordered.to_sql


    # collapse the providers with the same name+technology (results in the MaxDown record being the one because of the sort order)
    @serving_providers = rel.ordered.to_a.uniq{|p| p.provider_name_dba + p.technology_name}

    # iterate over each group - Residential first (non_res_only = 'N')
    # @serving_providers.group_by(&:non_res_only).each do |non_res, providers|
    #   # non_res will be 'N' or 'Y'
    #   providers.each do |provider|
    #     # provider row
    #   end
    # end

    respond_to do |format|
      format.html { render layout: false }
      format.json { render json: @serving_providers, only: [:fid], methods: [:name, :dba_name, :max_down_description, :max_up_description, :transmission_technology, :url] }
      format.xml  { render xml: @serving_providers, only: [:fid], methods: [:name, :dba_name, :max_down_description, :max_up_description, :transmission_technology, :url] }
    end
  end

  def district
    result = District.select("ST_AsText(ST_Transform(ST_Centroid(geometry), 900913)) as center").where(name: params[:name]).first

    respond_to do |format|
      format.html { render layout: false }
      format.json { render json: result }
      format.xml  { render xml: result }
    end
  end

  def styles
    rel = case params[:by]
    when "county"
        result = County.where(name: params[:name]).select(:id).first
    when "zip"
        result = ZipCode.where(name: params[:name]).select(:id).first
    when "district"
        result = District.where(name: params[:name]).select(:id).first
    end

    respond_to do |format|
      format.html { render layout: false }
      format.json { render json: result }
      format.xml  { render xml: result }
    end
  end

  private
  def set_variables_for_view
    # set up all global variable here so that the view does not reference classes - to allow it to be portable to the enc_website project
    @districts_options = District.where(state_id: @map.state_id).order(:geoid).pluck(:name, :id)
    @technology_map_styles = MapStyle.where(map_id: @map.id, layerable_type: "Technology").sort_by{|ms| ms.layerable.position}
    @cai_category_map_styles = MapStyle.where(map_id: @map.id, layerable_type: "CaiCategory").sort_by{|ms| ms.layerable.position}
    @wms_path = Settings[:geoserver][:wms_path].present? ? Settings[:geoserver][:wms_path] :
               "#{Settings[:geoserver][:protocol]}://#{Settings[:geoserver][:host]}:#{Settings[:geoserver][:port]}/geoserver/#{Settings[:geoserver][:workspace]}/wms"
    @technology_relation = Technology
    @cai_category_relation = CaiCategory
    # routes specific to this app
    @provider_service_path = provider_service_path
    @style_path = style_path
    @district_path = district_path
  end

end