namespace :openmap do

    ###############################################################################################
    # Step 1 - Review and set configuration settings
    #
    #  Once these settings are reviewed and prepared run each successive rake task to set things up
    #
    #   rake openmap:setup
    #   rake openmap:load_census_shapefiles
    #   rake openmap:load_providers_and_institutions
    #   rake openmap:configure_geoserver
    #
    #   --OR--
    #
    #   rake openmap:doitall
    #
    #
    #  Big enhancement todo: make this runnable with multiple maps
    ###############################################################################################


    # find the statefp code from the census state shapefile data and set that value here
    # NOTE: if you want a custom map for a part of a state, or multi-state, you will need to update the geometry as desired - after Step 3
    STATE_FP_FOR_MAP_GEOMETRY = "37"

    # by default defaults its center to the centroid of the State. Set the LNG,LAT values (in projection 900913) if you want to tweak the center of the map
    MAP_CENTROID = { lng: -8890000, lat: 4223072 }

    # census shape files data top directory - by convention, we put this under db, and it follows the Census Tiger sub-directory pattern (see Step 2)
    CENSUS_DIR = "#{Rails.root}/db/census_data/"

    # put all shape files in this one directory, with no sub-directories
    MAP_DATA_DIR = "#{Rails.root}/db/map_data/"

    # put image files for CAI icons in this directory
    CAI_ICON_DIR = "#{Rails.root}/public/"

    # distinct geometries for provider + transtech + maxdown + maxup + nonres
    PROVIDER_SERVICE_QUERY_SHAPE_FILE = "AllCoverageF14_OSMQuery"                   #  ==> do not include the .SHP extension

    # coverage shapefile per technology
    SERVED_AREA_DISPLAY_SHAPE_FILE = "AllCoverageF14_OSMDisplay"                       #  ==> do not include the .SHP extension

    # community anchor institutions
    CAI_INSTITUTION_SHAPE_FILE = "CAIF14_OSM"                               #  ==> do not include the .SHP extension

    # set this to false if you want the entire Unites States counties and congressional districts loaded -- will take more time and space
    IMPORT_COUNTIES_AND_DISTRICTS_ONLY_FOR_SELECTED_STATE = true

    # an array of string patterns suitable for SQL, as in '27%' --set to nil or an empty array to load all zip codes
    IMPORT_ONLY_ZIP_CODES_WITH_PATTERNS = ['27%', '28%']   # speed up TESTING       ['27%', '28%']

    # set these to true to union all the provider served areas and automatically create the display layers
    # for now we will not do this, and instead load a separate simplified display layer shape file
    UNION_PROVIDER_SHAPES_INTO_TECHNOLOGY_GEOMETRY = false
    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! KEEP THIS SET TO false !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    # aka, let the script build the display layer
    # in the near future, if using FCC data that does not include any individual address level data, then
    # this feature can be an option
    UNION_PROVIDER_SHAPES_FOR_MAP = false

    #????????????
    # Configure map geometry - Basic object for display on the map, will be shown by default
    INTERSECTS_OR_OVERLAPS = "overlaps"                             # Allows to change between intersecting, overlapping, or other functions
    WHAT_TO_SHOW_THAT_OVERLAPS_WITH_MAP_GEOMETRY = "county"         # state, zip, district, coverage geometry, etc.

    # if Postgres binaries psql and shp2pgsql are not in your path, prepend the full path to run the binaries here
    PSQL = "psql"               # e.g. /Applications/Postgres.app/Contents/Versions/9.3/bin/psql -h localhost -d openmap -U openmap
    SHP2PGSQL = "shp2pgsql"     # e.g. /Applications/Postgres.app/Contents/Versions/9.3/bin/shp2pgsql

    # in Step 2 below, you willimport the census Tiger Line files. You must download these and place in CENSUS_DIR (specified above)
    # set the YEAR here, and confirm that the file name formats in the census_shapefiles hash in Step 2 are correct, e.g. "tl_2013_us_state", "tl_2013_us_zcta510"
    TIGER_LINE_YEAR = "2014"

    # normally this should be set to true because the temp shapefile tables are not needed. Set to false for debugging if you wish.
    DROP_TEMP_TABLES = false

    # Set to true if you don't want the task to delete the workspace if it already exists, and rebuild
    DIE_IF_WORKSPACE_EXISTS = false

    # convenience task, mainly during development, to do the whole shebang - you must have already done the rake db:drop, db:create, and db:migrate
    task :doitall => [ 'openmap:setup', 'openmap:load_census_shapefiles', 'openmap:load_providers_and_institutions', 'openmap:configure_geoserver' ]


    #################################################
    # Step 2 - load the basic census data shape files
    #################################################
    task :setup => :environment do
        connection = ActiveRecord::Base.connection

        # purge old data
        [:institution, :provider, :provider_service, :served_area].reverse.each{ |key| connection.execute("DELETE FROM #{key.to_s}") }
        [:state, :county, :district, :zip_code].reverse.each{ |key| connection.execute("DELETE FROM #{key.to_s}") }
        [:speed_tier, :technology, :tech_type, :cai_category, :map_style].reverse.each{ |key| connection.execute("DELETE FROM #{key.to_s}") }

        puts "Creating Speed Tiers..."
        SpeedTier.where(code:  1).first_or_create!(description: "<= 200 kbps")
        SpeedTier.where(code:  2).first_or_create!(description: "> 200 kbps and < 768 kbps")
        SpeedTier.where(code:  3).first_or_create!(description: ">= 768 kbps and < 1.5mbps")
        SpeedTier.where(code:  4).first_or_create!(description: ">= 1.5 mbps and < 3 mbps")
        SpeedTier.where(code:  5).first_or_create!(description: ">= 3 mbps and < 6 mbps")
        SpeedTier.where(code:  6).first_or_create!(description: ">= 6 mbps and < 10 mbps")
        SpeedTier.where(code:  7).first_or_create!(description: ">= 10 mbps and < 25 mbps")
        SpeedTier.where(code:  8).first_or_create!(description: ">= 25 mbps and < 50 mbps")
        SpeedTier.where(code:  9).first_or_create!(description: ">= 50 mbps and < 100 mbps")
        SpeedTier.where(code: 10).first_or_create!(description: ">= 100 mbps and < 1 gbps")
        SpeedTier.where(code: 11).first_or_create!(description: ">= 1 gpbs")

        # define the set of Technologies that the transtech "TechType" codes will roll up into:
        puts "Creating technology and tech_type values..."
        cable     = Technology.where(name: "Cable"          ).first_or_create!(position: 1)
        dsl       = Technology.where(name: "DSL"            ).first_or_create!(position: 2)
        fiber     = Technology.where(name: "Fiber"          ).first_or_create!(position: 3)
        fixed     = Technology.where(name: "Fixed Wireless" ).first_or_create!(position: 4)
        mobile    = Technology.where(name: "Mobile Wireless").first_or_create!(position: 5)
        satellite = Technology.where(name: "Satellite"      ).first_or_create!(position: 6)
        other     = Technology.where(name: "Other"          ).first_or_create!(position: 7)

        # create map
        map = Map.where(name: Settings[:map][:name]).first_or_create!

        # define default styles for each Technology - we specifically do not show Satellite on the map - it's like Chickenman -- He's everywhere
        MapStyle.where(map_id: map.id, layerable_type: "Technology", layerable_id: cable.id).first_or_create!( name: "cable",  color: "#0000FF", opacity: 0.7)       # blue
        MapStyle.where(map_id: map.id, layerable_type: "Technology", layerable_id: dsl.id).first_or_create!(   name: "dsl",    color: "#00FF00", opacity: 0.7)       # green
        MapStyle.where(map_id: map.id, layerable_type: "Technology", layerable_id: fiber.id).first_or_create!( name: "fiber",  color: "#804000", opacity: 0.7)       # brown
        MapStyle.where(map_id: map.id, layerable_type: "Technology", layerable_id: fixed.id).first_or_create!( name: "fixed",  color: "#FF00FF", opacity: 0.7)       # magenta
        MapStyle.where(map_id: map.id, layerable_type: "Technology", layerable_id: mobile.id).first_or_create!(name: "mobile", color: "#FFFF00", opacity: 0.7)       # yellow
        MapStyle.where(map_id: map.id, layerable_type: "Technology", layerable_id: other.id).first_or_create!( name: "other",  color: "#808080", opacity: 0.7)       # gray

        # create and map each tech_type we know of to the appropriate technology
        puts "Creating tech_types..."
        TechType.where(code: 10).first_or_create!(technology_id: dsl.id,       name: "Asymmetric xDSL")
        TechType.where(code: 20).first_or_create!(technology_id: dsl.id,       name: "Symmetric xDSL")
        TechType.where(code: 30).first_or_create!(technology_id: other.id,     name: "Other Copper Wireline")
        TechType.where(code: 40).first_or_create!(technology_id: cable.id,     name: "Cable Modem - DOCSIS 3.0")
        TechType.where(code: 41).first_or_create!(technology_id: cable.id,     name: "Cable Modem - Other")
        TechType.where(code: 50).first_or_create!(technology_id: fiber.id,     name: "Optical carrier/Fiber to the end user")
        TechType.where(code: 60).first_or_create!(technology_id: satellite.id, name: "Satellite")
        TechType.where(code: 70).first_or_create!(technology_id: fixed.id,     name: "Terrestrial Fixed Wireless - Unlicensed")
        TechType.where(code: 71).first_or_create!(technology_id: fixed.id,     name: "Terrestrial Fixed Wireless - Licensed")
        TechType.where(code: 80).first_or_create!(technology_id: mobile.id,    name: "Terrestrial Mobile Wireless")
        TechType.where(code: 90).first_or_create!(technology_id: other.id,     name: "Electric Power Line")
        TechType.where(code:  0).first_or_create!(technology_id: other.id,     name: "All Other")

        puts "Creating CAI Categories..."
        library        = CaiCategory.where(code: 2).first_or_create!(position: 0, display: true,  name: 'Library')
        school         = CaiCategory.where(code: 1).first_or_create!(position: 1, display: true,  name: 'School')
        post_secondary = CaiCategory.where(code: 5).first_or_create!(position: 2, display: true,  name: 'Post Secondary School')
        government     = CaiCategory.where(code: 6).first_or_create!(position: 3, display: true,  name: 'Government')
        lack_access    = CaiCategory.where(code: 3).first_or_create!(position: 4, display: true,  name: 'Lack of Access')
        dont_care      = CaiCategory.where(code: 4).first_or_create!(position: 9, display: false, name: 'Public Safety')
        dont_care      = CaiCategory.where(code: 7).first_or_create!(position: 9, display: false, name: 'Other community support')

        # need a style for each category to be displayed ont he map
        MapStyle.where(map_id: map.id, layerable_type: "CaiCategory", layerable_id: library.id).first_or_create!(        name: "library",        color: "#663399", opacity: 1, graphic_name: 'star_yellow.svg')
        MapStyle.where(map_id: map.id, layerable_type: "CaiCategory", layerable_id: school.id).first_or_create!(         name: "school",         color: "#FF6600", opacity: 1, graphic_name: 'triangle_orange.svg')
        MapStyle.where(map_id: map.id, layerable_type: "CaiCategory", layerable_id: post_secondary.id).first_or_create!( name: "post_secondary", color: "#0000FF", opacity: 1, graphic_name: 'triangle_purple.svg')
        MapStyle.where(map_id: map.id, layerable_type: "CaiCategory", layerable_id: government.id).first_or_create!(     name: "government",     color: "#0000FF", opacity: 1, graphic_name: 'circle_purple.svg')
        MapStyle.where(map_id: map.id, layerable_type: "CaiCategory", layerable_id: lack_access.id).first_or_create!(    name: "lack_access",    color: "#0000FF", opacity: 1, graphic_name: 'cross_red.svg')

        # map disclaimer text
        map.disclaimer = "
        <p>
            Welcome to the NC Broadband Map. This tool allows you to interact with a state map to search for broadband providers.
            At the top of the map are controls that allow you to search for a location, which can be an address, zip code, or county.
            You can also select a legislative district from the North Carolina State House of Representatives, North Carolina State Senate, or United States House of Representatives.
            When you make one of these searches, an outline of the area will display on the map
            and a list of the Provides serving that location or area will display on the left side.
        </p>
        <p>
            To get more detailed information on the features of this map tool and help on how to use it, click the 'Help' button (with the ? question mark) in the top right corner of the page.
        </p>
        <p>
            YOUR USE OF THIS WEBSITE AND THE INFORMATION AVAILABLE BY USING THIS WEBSITE IS CONDITIONED UPON YOUR ACCEPTANCE OF THESE TERMS AND CONDITIONS AND ANY OTHER POLICIES POSTED ON THE WEBSITE.
            Your use of the Website and information confirms your agreement to the terms and conditions of this Agreement: if you do not agree, do not use or access the Website or information.
            The NC Department of Commerce (Commerce) reserves the right to modify this Agreement at any time without prior notice.  Your use of this site after any such modification constitutes your
            agreement to be bound by the terms and conditions of this Agreement as modified.  It is your responsibility to review these terms and conditions prior to each use of the website.
            By continuing to use the website, you agree to any such changes.  The last date this Agreement was modified is June 26, 2014.
        </p>
        <p>
            Commerce is hosting this broadband mapping and is solely responsible for its content. The site and the information contained therein are being provided by Commerce as a public service to the
            citizens of North Carolina. The mapping and other associated information presented herein is only as accurate as the source data provided by the actual broadband service providers that
            participated in this program, and may not be all inclusive of the services provided in a particular area. Furthermore, the mapping and other information herein is periodically updated
            (semi-annually) and therefore may not reflect the most current information. The mapping and other information herein was developed from broadband service provider data represented as
            current by the providers as of December 31, 2013.
        </p>
        <p>
            Broadband Service Area Granularity: The broadband service area coverage depicted herein is derived from data collected from broadband service providers under the requirements of the National
            Telecommunications & Information Administration.  For the mapview, the data has been aggregated to the granularity of either the census block area, or street centerline segment and buffered,
            depending upon population densities as determined by the U.S. Census Bureau. Persons using this website should understand that a provider’s area is depicted to the entire census block or
            buffered street segment even if they service only a portion of the census block or street segment, therefore the coverage may be overstated in some areas. For the query function of the map,
            data also includes broadband availability information specific to address points in some cases. Because the queried data contains this additional level of granularity, queried results may
            be slightly different than the map viewer alone. To determine broadband service coverage to a finer granularity, the actual broadband service providers should be contacted.
        </p>
        <p>
            Data Validation/Enhancements: The mapping and other information contained herein is a work in progress and, as noted above, will be periodically updated. Various additional data collection
            methods are used to assess the accuracy of the broadband service provider’s data. Continued assessment will help to increase confidence in the data with each update. This website also
            includes a feedback tool for users to provide comments and address broadband service availability in their area. The public is encouraged to be a part of the broadband mapping validation
            process by using this feedback tool to provide their valuable input.
        </p>
        <p>
            Warranties and Disclaimer: All information on this site is provided on an “As-Is” and “As Available” basis and you agree to use it at your own risk.  Commerce makes no warranty, representation
            or guarantee of any kind, express or implied, without limitation, regarding either the accuracy, reliability, timeliness, quality or completeness of mapping or other information provided herein
            or the sources thereof. Persons using this website should understand that Commerce does not assume liability for any errors, omissions, or inaccuracies in the mapping or other information
            provided herein regardless of the cause of such or any decision made, action taken, or action not taken by the user in reliance upon any maps or information provided herein.
        </p>
        <p>
            Third Party Websites: This web site may contain links to other sites. Commerce is not responsible for the privacy policies and practices of these other sites. Hyperlinks are to be accessed at
            your own risk, and Commerce makes no representations or warranties about the content, completeness or accuracy of these hyperlinks or the sites hyperlinked to this site. Further, the inclusion
            of any hyperlink to a third-party site does not imply endorsement of that site by Commerce.
        </p>
        <p>
            Indemnification: You agree to indemnify, hold harmless and defend Commerce and its licensors, suppliers, assignees, shareholders, directors, officers, employees and agents from and against
            any action, cause, claim, damage, debt, demand or liability, including reasonable costs and attorneys’ fees, asserted by any person, arising out of or relating to: (a) your use of the site,
            including, without limitation, any data or work transmitted or received by you; and (b) any use of the information, including, without limitation, any statement, data or content made,
            transmitted or republished by you.
        </p>
        <p>
            I understand all terms and conditions contained herein, as well as all rights and obligations created.
        </p>"
        map.save!

        if MAP_CENTROID.present?
            ActiveRecord::Base.connection.execute("UPDATE map SET centroid = ST_MakePoint(#{MAP_CENTROID[:lng]}, #{MAP_CENTROID[:lat]}) WHERE id = #{map.id}")
        end

    end


    #################################################
    # Step 3 - load the basic census data shape files
    #################################################
    task :load_census_shapefiles => :environment do
        # we *could* build in the fetching of the census data files here, but for now will require the user to pre-download
        # RestClient.get('http://www2.census.gov/geo/tiger/TIGER2014/STATE/tl_2014_us_state.zip')

        # script to fetch and stash on the server:
        shell_script = "
         cd db/census_data
         mkdir tl_2014_us_state;   cd tl_2014_us_state;   wget http://www2.census.gov/geo/tiger/TIGER2014/STATE/tl_2014_us_state.zip;   unzip tl_2014_us_state.zip;   cd ..
         mkdir tl_2014_us_county;  cd tl_2014_us_county;  wget http://www2.census.gov/geo/tiger/TIGER2014/COUNTY/tl_2014_us_county.zip; unzip tl_2014_us_county.zip;  cd ..
         mkdir tl_2014_us_cd114;   cd tl_2014_us_cd114;   wget http://www2.census.gov/geo/tiger/TIGER2014/CD/tl_2014_us_cd114.zip;      unzip tl_2014_us_cd114.zip;   cd ..
         mkdir tl_2014_us_zcta510; cd tl_2014_us_zcta510; wget http://www2.census.gov/geo/tiger/TIGER2014/ZCTA5/tl_2014_us_zcta510.zip; unzip tl_2014_us_zcta510.zip; cd ..
        "

        connection = ActiveRecord::Base.connection

        if Technology.where(name: "Cable").first.nil?
            puts "Please run rake openmap:setup first"
            exit 1
        end

        # build dynamic where qualifiers to trim down the amount of data loaded
        state_where_qualifier = IMPORT_COUNTIES_AND_DISTRICTS_ONLY_FOR_SELECTED_STATE ? " WHERE t.statefp = '#{STATE_FP_FOR_MAP_GEOMETRY}' " : ""
        zip_code_qualifier = IMPORT_ONLY_ZIP_CODES_WITH_PATTERNS.present? && IMPORT_ONLY_ZIP_CODES_WITH_PATTERNS.map{|p| "zcta5ce10 LIKE '#{p}'"}.join(" OR ") || ""
        zip_code_qualifier = " WHERE #{zip_code_qualifier}" if zip_code_qualifier.present?

        census_shapefiles = {
            state: {
                dir: "tl_#{TIGER_LINE_YEAR}_us_state",
                sql: "INSERT INTO state (gid, name, geoid, statefp, geometry)
                        (SELECT t.gid, t.name, t.geoid, t.statefp, t.geom
                         FROM temp_state t
                         #{state_where_qualifier})"
            },
            county: {
                dir: "tl_#{TIGER_LINE_YEAR}_us_county",
                sql: "INSERT INTO county (gid, name, geoid, state_id, geometry)
                        (SELECT t.gid, t.name, t.geoid, state.id, t.geom
                        FROM temp_county t
                        JOIN state ON state.statefp = t.statefp
                        #{state_where_qualifier})"
            },
            district: {
                dir: "tl_#{TIGER_LINE_YEAR}_us_cd114",
                sql: "INSERT INTO district (gid, name, geoid, state_id, geometry)
                        (SELECT t.gid, t.namelsad, t.geoid, state.id, t.geom
                        FROM temp_district t
                        JOIN state ON state.statefp = t.statefp
                        #{state_where_qualifier})"
            },
            # No state identifier for ZCTA, select by intersection or load all?
            zip_code: {
                dir: "tl_#{TIGER_LINE_YEAR}_us_zcta510",
                sql: "INSERT INTO zip_code (gid, name, geoid, geometry)
                            (SELECT gid, zcta5ce10, geoid10, geom
                             FROM temp_zip_code
                             #{zip_code_qualifier})"
            }
        }

        # delete the existing data, to be replaced - must delete dependancies last so reverese the hash
        census_shapefiles.keys.reverse.each{|key|
            puts "Emptying existing #{key}"
            connection.execute("DELETE FROM #{key.to_s}")
        }

        census_shapefiles.each{|key,val|
            puts "Loading #{val[:dir]}"
            shapefile = "#{CENSUS_DIR}/#{val[:dir]}/#{val[:dir]}.shp"
            connection.execute("DROP TABLE IF EXISTS temp_#{key}")
            ENV['PGPASSWORD'] = "#{psql_password}"
            %x( #{SHP2PGSQL} -W 'latin1' -I -s 4269 #{shapefile} temp_#{key} | #{psql_command} )
            ENV['PGPASSWORD'] = nil
            connection.execute(val[:sql])
            connection.execute("DROP TABLE temp_#{key}") if DROP_TEMP_TABLES
        }

        if State.where(statefp: STATE_FP_FOR_MAP_GEOMETRY).select(:id).first.nil?
            puts "WARNING: the STATE_FP_FOR_MAP_GEOMETRY value of #{STATE_FP_FOR_MAP_GEOMETRY} was not found in the Census State data."
        end
    end


    #################################################
    # Step 4 - load the provider detail query data
    #################################################
    task :load_providers_and_institutions => :environment do
        connection = ActiveRecord::Base.connection

        # get settings from database.yml
        database_config = Rails.configuration.database_configuration[Rails.env]

        # Create the map record and find and assign the state geometry for our selected state
        state = State.where(statefp: STATE_FP_FOR_MAP_GEOMETRY).select(:id).first

        # create the map if not present (should be there), and assign to our state
        map = Map.where(name: Settings[:map][:name]).first_or_create!

        # set the selected state geometry into the map
        connection.execute("UPDATE map
                            SET state_id = state.id, geometry = state.geometry
                            FROM state
                            WHERE map.id = #{map.id} AND state.id = #{state.id}")
        # TIP: select id,name,substring(ST_AsText(geometry) from 1 for 100) from map;

        #
        # Import providers shapefile
        # example shp2pgsql script run
        # shp2pgsql -W 'latin1' -I -s 4269 db/map_data/unified_query_layer.shp temp_provider | psql openmap
        puts "Loading providers from #{PROVIDER_SERVICE_QUERY_SHAPE_FILE}..."

        shapefile = "#{MAP_DATA_DIR}/#{PROVIDER_SERVICE_QUERY_SHAPE_FILE}.shp"
        connection.execute("DROP TABLE IF EXISTS temp_provider")
        ENV['PGPASSWORD'] = "#{psql_password}"
        %x( #{SHP2PGSQL} -W 'latin1' -I -s 4269 #{shapefile} temp_provider | #{psql_command} )
        ENV['PGPASSWORD'] = nil

        # must first remove provider_service rows otherwise foreign key constraints will complain
        connection.execute("DELETE FROM provider_service")

        # get the imported data into our tables
        connection.execute("DELETE FROM provider")
        connection.execute("INSERT INTO provider (name, name_dba)
                            (SELECT DISTINCT provname, dbaname FROM temp_provider)")

        # TODO: website to be added thru admin
        # # update the website URL in our provider table
        # connection.execute("UPDATE provider AS p
        #                     SET website = t.url
        #                     FROM temp_provider AS t
        #                     WHERE t.provname || t.dbaname = p.name || p.name_dba")

        # Populate tech_type table with any detected codes not previously defined
        connection.execute("INSERT INTO tech_type (code)
                            (SELECT DISTINCT transtech from temp_provider WHERE transtech NOT IN (select code::int FROM tech_type))")

        # populate any detected speed tier codes not already created
        connection.execute("INSERT INTO speed_tier (code)
                    (SELECT DISTINCT maxaddown::int FROM temp_provider WHERE maxaddown::int NOT IN (select code FROM speed_tier))")
        connection.execute("INSERT INTO speed_tier (code)
                    (SELECT DISTINCT maxadup::int FROM temp_provider WHERE maxadup::int NOT IN (select code FROM speed_tier))")

        puts "Creating provider_service records..."
        connection.execute("INSERT INTO provider_service (provider_id, technology_id, speed_up_id, speed_down_id, geometry)
                    (SELECT p.id, t.id, stup.id, stdown.id, tp.geom
                     FROM temp_provider AS tp
                     JOIN provider p ON p.name || p.name_dba = tp.provname || tp.dbaname
                     JOIN tech_type tt ON tt.code = tp.transtech::int
                     JOIN technology t ON t.id = tt.technology_id
                     JOIN speed_tier stup ON stup.code = tp.maxadup::int
                     JOIN speed_tier stdown ON stdown.code = tp.maxaddown::int)
                   ")

        # Now we can drop the temp_provider table
        connection.execute("DROP TABLE IF EXISTS temp_provider") if DROP_TEMP_TABLES


        # load the institutions - category = key - fresh by deleteing rows first
        puts "Loading institutions from #{CAI_INSTITUTION_SHAPE_FILE}"
        connection.execute("DELETE FROM institution")

        shapefile = "#{MAP_DATA_DIR}/#{CAI_INSTITUTION_SHAPE_FILE.gsub('.shp','')}.shp"
        connection.execute("DROP TABLE IF EXISTS temp_institution")
        ENV['PGPASSWORD'] = "#{psql_password}"
        %x( #{SHP2PGSQL} -W 'latin1' -I -s 4269 #{shapefile} temp_institution | #{psql_command} )
        ENV['PGPASSWORD'] = nil

        # Populate cai_category table with any detected codes not previously defined
        connection.execute("INSERT INTO cai_category (code)
                            (SELECT DISTINCT caicat::int FROM temp_institution WHERE caicat::int NOT IN (select code FROM cai_category))")
        # add the institutions
        connection.execute("INSERT INTO institution (name, address, url, caiid, geometry, cai_category_id)
                            (SELECT t.anchorname, t.address, t.url, t.caiid, t.geom, c.id
                            FROM temp_institution AS t
                            JOIN cai_category c ON c.code = t.caicat::int)")

        # we're done with this temp table
        connection.execute("DROP TABLE temp_institution") if DROP_TEMP_TABLES


        if UNION_PROVIDER_SHAPES_INTO_TECHNOLOGY_GEOMETRY
            # Should fix any ring self intersections in the provider_service table
            # After that it will be safe to union the provider_services into a map geometry
            connection.execute("UPDATE provider_service AS c
                                SET geometry = ST_MakeValid(c.geometry)
                                WHERE ST_IsValid(c.geometry) = false")

            # Creates technology geometries from provider_services -- if we go that route
            ############## Needs work but we're not going to do this for a while
            puts "Go to dinner, this will take a while..."
            connection.execute("INSERT INTO served_area (technology_id, geometry)
                                JOIN technology AS t
                                SET geometry = ST_UNION(ARRAY(SELECT geometry FROM provider_service WHERE provider_service.technology_id = t.id))")

        else
            # we will have gotten a display layer shapefile SERVED_AREA_DISPLAY_SHAPE_FILE, so import it here
            puts "Loading display areas from #{SERVED_AREA_DISPLAY_SHAPE_FILE}"
            connection.execute("DELETE FROM served_area")

            shapefile = "#{MAP_DATA_DIR}/#{SERVED_AREA_DISPLAY_SHAPE_FILE.gsub('.shp','')}.shp"
            connection.execute("DROP TABLE IF EXISTS temp_display")
            ENV['PGPASSWORD'] = "#{psql_password}"
            %x( #{SHP2PGSQL} -W 'latin1' -I -s 4269 #{shapefile} temp_display | #{psql_command} )
            ENV['PGPASSWORD'] = "#{psql_password}"

            # if any technology labels exist in the temp_display shapefile that are not matched in our technology table, we will have a problem
            errors = []
            result = connection.execute("SELECT DISTINCT technology FROM temp_display")
            result.each{|row|
                if Technology.where("lower(name) = ?", row['technology'].downcase).first.nil?
                    errors << "Error: Technology '#{row['technology']}' detected in #{SERVED_AREA_DISPLAY_SHAPE_FILE} but not defined in technology table!"
                end
            }
            if errors.present?
                puts errors.join("\n")
                exit 1
            end


            # helpful SQL:
            # select s.id, s.technology_id, s.commercial, s.residential, t.name from served_area s join technology t on s.technology_id = t.id

            if false  ######## we can't do this now - the query takes forever
                # puts "Creating served_area records... ***** go get some coffee - this wil take a while *****"
                # populate the served area table with one row per technology in the temp_display table
                connection.execute("INSERT INTO served_area (technology_id)
                                    (SELECT DISTINCT t.id FROM temp_display AS d LEFT JOIN technology t ON lower(t.name) = lower(d.technology))")

                # update each row and set the geometry to the union of all rows with the same technology
                connection.execute("UPDATE served_area SET geometry = ST_UNION(ARRAY(
                                                                                SELECT geom
                                                                                FROM temp_display
                                                                                JOIN technology ON lower(technology.name) = lower(temp_display.technology)
                                                                                WHERE technology.id = served_area.technology_id))")
            end

# select gid,res,nonres,technology from temp_display;
#  gid | res | nonres |   technology
# -----+-----+--------+-----------------
#    1 |   0 |      1 | DSL
#    2 |   0 |      1 | Fiber
#    3 |   0 |      1 | Other
#    4 |   1 |      0 | Cable
#    5 |   1 |      1 | Cable
#    6 |   1 |      1 | Fiber
#    7 |   1 |      1 | Fixed Wireless
#    8 |   1 |      1 | Mobile Wireless
#    9 |   1 |      1 | DSL
# (9 rows)
#
# we are hacking this query for the time being: where res=1 and nonres=1 or technology = 'Other';

            puts "Creating served_area records..."
            connection.execute("INSERT INTO served_area (technology_id, commercial, residential, geometry)
                                (SELECT t.id, d.nonres=1, d.res=1, d.geom
                                 FROM temp_display AS d
                                 LEFT JOIN technology t ON lower(t.name) = lower(d.technology)
                                 WHERE (res=1 AND nonres=1) OR technology = 'Other')
                              ")

           connection.execute("DROP TABLE temp_display") if DROP_TEMP_TABLES
        end

    end   # load_providers_and_institutions



    #########################################################
    # Step 5 - configure the Geoserver - should be done once
    #########################################################
    task :configure_geoserver => :environment do
        connection = ActiveRecord::Base.connection

        # get settings from database.yml
        database_config = Rails.configuration.database_configuration[Rails.env]


        # select only needed columns to prevent the entire geometry from being slurped into the in memory model object
        map = Map.where(name: Settings[:map][:name]).select(:id, :name).first

        if map.nil?
            puts "*************************************************************************************"
            puts "Error: No Map record found in database for map name: '#{Settings[:map][:name]}'"
            puts "Please check config.yml or re-run rake geoserver:setup"
            puts "*************************************************************************************"
            exit 1
        end

        # Creates views to act as layer tables for the technologies
        puts "Creating views for served_areas..."
        ServedArea.order(:id).select(:id).each do |sa|
            connection.execute("DROP VIEW IF EXISTS view_served_area_#{sa.id}")
            sql = "CREATE VIEW view_served_area_#{sa.id} AS
                    SELECT served_area.id, technology.name, served_area.geometry
                    FROM served_area
                    JOIN technology ON technology.id = served_area.technology_id
                    WHERE served_area.id = #{sa.id}"
            connection.execute(sql)
        end

        # have to do the same with Institutions - need to create a view for each CAI category that is set to be visible
        puts "Creating views for institutions per cai_category..."
        CaiCategory.where(display: true).order(:position).select(:id).each do |cai|
            connection.execute("DROP VIEW IF EXISTS view_cai_#{cai.id}")
            sql = "CREATE VIEW view_cai_#{cai.id} AS
                    SELECT id, name, geometry
                    FROM institution
                    WHERE cai_category_id = #{cai.id}"
            connection.execute(sql)
        end

        ##################################
        # Setup Geoserver with REST calls
        ##################################

        GEOSERVER_WORKSPACE = Settings[:geoserver][:workspace]
        GEOSERVER_DATASTORE = Settings[:geoserver][:datastore]

        BASE_URL = "http://#{Settings[:geoserver][:username]}:#{Settings[:geoserver][:password]}@#{Settings[:geoserver][:host]}:#{Settings[:geoserver][:port]}/geoserver/rest"
        BASE_URL_WORKSPACE = "#{BASE_URL}/workspaces/#{GEOSERVER_WORKSPACE}"

        puts "Configuring Geoserver at: #{BASE_URL}"

        workspace_exists = RestClient.get("#{BASE_URL}/workspaces/#{GEOSERVER_WORKSPACE}.html").present? rescue false

        if workspace_exists
            if DIE_IF_WORKSPACE_EXISTS
                puts "*************************************************************************************"
                puts "Error: The workspace '#{GEOSERVER_WORKSPACE}' already exists! "
                puts "Please login to the Geoserver and manually remove the workspace then rerun this task."
                puts "*************************************************************************************"
                exit 1
            end
            puts "Deleting existing Geoserver workspace #{GEOSERVER_WORKSPACE}..."
            # curl -v -u admin:geoserver -XDELETE http://localhost:8080/geoserver/rest/workspaces/OpenMap?recurse=true
            ok = RestClient.delete("#{BASE_URL}/workspaces/#{GEOSERVER_WORKSPACE}?recurse=true") rescue false

            exit 2 unless ok
        end


        # Create workspace inside GeoServer
        puts "Creating Geoserver workspace #{GEOSERVER_WORKSPACE}..."
        call_rest(:post, "#{BASE_URL}/workspaces", "<workspace><name>#{GEOSERVER_WORKSPACE}</name></workspace>")


        # Create datastore inside Geoserver - this acts as link to PostGIS database
        puts "Creating Geoserver datastore..."
        xml = "<dataStore>
                 <name>#{GEOSERVER_DATASTORE}</name>
                 <connectionParameters>
                      <host>#{database_config["host"]}</host>
                      <port>#{database_config["port"] || '5432'}</port>
                      <database>#{database_config["database"]}</database>
                      <schema>public</schema>
                      <user>#{database_config["username"]}</user>
                      <passwd>#{database_config["password"]}</passwd>
                      <dbtype>postgis</dbtype>
                 </connectionParameters>
               </dataStore>"
        call_rest(:post, "#{BASE_URL}/workspaces/#{GEOSERVER_WORKSPACE}/datastores", xml)


        # Create layer references and the styles in the GeoServer - these are what get displayed on the map by virtue of a style
        puts "Creating Geoserver served_area featuretypes..."
        ServedArea.order(:id).select(:id, :technology_id).each do |sa|
            # create the layer
            call_rest(:post, "#{BASE_URL}/workspaces/#{GEOSERVER_WORKSPACE}/datastores/#{GEOSERVER_DATASTORE}/featuretypes",
                             "<featureType>
                                <name>view_served_area_#{sa.id}</name>
                              </featureType>")

            # now create the style
            view = "view_served_area_#{sa.id}"
            mapstyle = MapStyle.where(map_id: map.id, layerable_type: "Technology", layerable_id: Technology.where(id: sa.technology_id).first).first

            xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
                    <sld:StyledLayerDescriptor xmlns=\"http://www.opengis.net/sld\" xmlns:sld=\"http://www.opengis.net/sld\" xmlns:ogc=\"http://www.opengis.net/ogc\" xmlns:gml=\"http://www.opengis.net/gml\" version=\"1.0.0\">
                      <sld:NamedLayer>
                        <sld:Name>#{view}</sld:Name>
                        <sld:UserStyle>
                          <sld:Name>#{view}</sld:Name>
                          <sld:Title>served area fill</sld:Title>
                          <sld:FeatureTypeStyle>
                            <sld:Name>name</sld:Name>
                            <sld:Rule>
                              <sld:PolygonSymbolizer>
                                <sld:Fill>
                                  <sld:CssParameter name=\"fill\">#{mapstyle.color}</sld:CssParameter>
                                  <sld:CssParameter name=\"opacity\">#{mapstyle.opacity}</sld:CssParameter>
                                </sld:Fill>
                              </sld:PolygonSymbolizer>
                            </sld:Rule>
                          </sld:FeatureTypeStyle>
                        </sld:UserStyle>
                      </sld:NamedLayer>
                    </sld:StyledLayerDescriptor>"

            # Upload style to GeoServer
            call_rest(:post, "#{BASE_URL_WORKSPACE}/styles", xml, 'application/vnd.ogc.sld+xml')

            # set the technology layer default style to the one we just created
            call_rest(:put, "#{BASE_URL}/layers/#{view}",
                                    "<layer>
                                      <defaultStyle>
                                        <name>#{view}</name>
                                        <workspace>#{GEOSERVER_WORKSPACE}</workspace>
                                      </defaultStyle>
                                    </layer>")
        end


        # Create layer references in the GeoServer - these are what get displayed on the map by virtue of a style
        puts "Creating Geoserver CAI featuretypes..."
        CaiCategory.where(display: true).order(:position).each do |cai|
            # create the layer
            call_rest(:post, "#{BASE_URL}/workspaces/#{GEOSERVER_WORKSPACE}/datastores/#{GEOSERVER_DATASTORE}/featuretypes",
                            "<featureType>
                                <name>view_cai_#{cai.id}</name>
                            </featureType>")

            # now create the style
            view = "view_cai_#{cai.id}"
            mapstyle = MapStyle.where(map_id: map.id, layerable_type: "CaiCategory", layerable_id: cai.id).first


            # It's important that the images that will be used on the map and next to the checkboxes are in the Rails asset pipeline
            # and also placed into the Geoserver data directory. They must be placed in the styles folder of the relevant workspace
            xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
                    <sld:StyledLayerDescriptor xmlns=\"http://www.opengis.net/sld\" xmlns:sld=\"http://www.opengis.net/sld\" xmlns:ogc=\"http://www.opengis.net/ogc\" xmlns:gml=\"http://www.opengis.net/gml\" version=\"1.0.0\">
                      <sld:NamedLayer>
                        <sld:Name>#{view}</sld:Name>
                        <sld:UserStyle>
                          <sld:Name>#{view}</sld:Name>
                          <sld:Title>CAI</sld:Title>
                          <sld:IsDefault>1</sld:IsDefault>
                          <sld:FeatureTypeStyle>
                            <sld:Name>name</sld:Name>
                            <sld:Rule>
                              <sld:PointSymbolizer>
                                <Graphic>
                                    <ExternalGraphic>
                                       <OnlineResource xmlns:xlink=\"http://www.w3.org/1999/xlink\" xlink:type=\"simple\" xlink:href=\"file://#{CAI_ICON_DIR}#{mapstyle.graphic_name}\" />
                                       <Format>image/svg+xml</Format>
                                    </ExternalGraphic>
                                    <sld:Size>12</sld:Size>
                                </Graphic>
                              </sld:PointSymbolizer>
                            </sld:Rule>
                          </sld:FeatureTypeStyle>
                        </sld:UserStyle>
                      </sld:NamedLayer>
                    </sld:StyledLayerDescriptor>"



#   <sld:Mark>
#     <WellKnownName>#{mapstyle.well_known_name}</WellKnownName>
#     <sld:Fill>
#       <sld:CssParameter name=\"fill\">#{mapstyle.color}</sld:CssParameter>
#     </sld:Fill>
#   </sld:Mark>
#   <sld:Size>6</sld:Size>

            # Upload style to GeoServer
            call_rest(:post, "#{BASE_URL_WORKSPACE}/styles?name=#{view}&raw=true", xml, 'application/vnd.ogc.sld+xml')

            # set the cai_category layer default style to the one we just created
            call_rest(:put, "#{BASE_URL}/layers/#{view}",
                            "<layer>
                                <defaultStyle>
                                    <name>#{view}</name>
                                    <workspace>#{GEOSERVER_WORKSPACE}</workspace>
                                </defaultStyle>
                            </layer>")

        end   # CaiCategory


        # Create a single county layer for all counties.
        puts "Creating Geoserver county featuretype..."
        call_rest("post", "#{BASE_URL}/workspaces/#{GEOSERVER_WORKSPACE}/datastores/#{GEOSERVER_DATASTORE}/featuretypes",
                          "<featureType>
                             <name>county</name>
                           </featureType>")

        # Create county styles
        # Default style will filter all counties intersected by the map geometry

        # Select counties inside the state
        # counties = County.where("name in ('Pender', 'Onslow', 'Nash', 'Wake', 'Durham')").select(:gid)     ## for debug testing
        counties = County.intersects_map(map).order(:gid).select(:gid, :id)

        # this is the default county map that is queryable
        sname = "openmap_#{map.id}_county_default"

        # this style is to display all the counties in the state. The OR filter is the query part to include all the counties
        xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <sld:StyledLayerDescriptor xmlns=\"http://www.opengis.net/sld\" xmlns:sld=\"http://www.opengis.net/sld\" xmlns:ogc=\"http://www.opengis.net/ogc\" xmlns:gml=\"http://www.opengis.net/gml\" version=\"1.0.0\">
          <sld:NamedLayer>
            <sld:Name>#{sname}</sld:Name>
            <sld:UserStyle>
              <sld:Name>#{sname}</sld:Name>
              <sld:Title>County polygon style</sld:Title>
              <sld:IsDefault>1</sld:IsDefault>
              <sld:FeatureTypeStyle>
                <sld:Name>name</sld:Name>
                <sld:Rule>
                    <sld:Name>County polygon</sld:Name>
                    <sld:Title>County polygon</sld:Title>
                    <ogc:Filter>
                        <ogc:Or>"
        counties.each do |county|
            xml += "
                            <ogc:PropertyIsEqualTo>
                                <ogc:PropertyName>gid</ogc:PropertyName>
                                <ogc:Literal>#{county.gid}</ogc:Literal>
                            </ogc:PropertyIsEqualTo>"
        end
            xml += "
                        </ogc:Or>
                    </ogc:Filter>
                    <sld:MinScaleDenominator>0</sld:MinScaleDenominator>
                    <sld:PolygonSymbolizer>
                        <sld:Stroke>
                            <sld:CssParameter name=\"stroke-opacity\">0.36</sld:CssParameter>
                        </sld:Stroke>
                    </sld:PolygonSymbolizer>
                    <sld:TextSymbolizer>
                        <sld:Label>
                            <ogc:PropertyName>name</ogc:PropertyName>
                        </sld:Label>
                        <sld:Font>
                          <sld:CssParameter name=\"font-family\">Verdana</sld:CssParameter>
                          <sld:CssParameter name=\"font-size\">12</sld:CssParameter>
                          <sld:CssParameter name=\"font-style\">normal</sld:CssParameter>
                          <sld:CssParameter name=\"font-weight\">bold</sld:CssParameter>
                        </sld:Font>
                        <sld:LabelPlacement>
                            <sld:PointPlacement>
                                <sld:AnchorPoint>
                                    <sld:AnchorPointX>0.0</sld:AnchorPointX>
                                    <sld:AnchorPointY>0.5</sld:AnchorPointY>
                                </sld:AnchorPoint>
                            </sld:PointPlacement>
                        </sld:LabelPlacement>
                        <sld:Halo>
                            <sld:Radius>2</sld:Radius>
                            <sld:Fill>
                                <sld:CssParameter name=\"fill\">#FFFFFF</sld:CssParameter>
                            </sld:Fill>
                        </sld:Halo>
                    </sld:TextSymbolizer>
                </sld:Rule>
              </sld:FeatureTypeStyle>
            </sld:UserStyle>
          </sld:NamedLayer>
        </sld:StyledLayerDescriptor>"

        # Upload style to GeoServer
        call_rest(:post, "#{BASE_URL_WORKSPACE}/styles", xml, 'application/vnd.ogc.sld+xml')

        # set the county layer default style to the one we just created
        # curl -v -u admin:geoserver -XPUT -H "Content-type: text/xml" -d "<layer><defaultStyle><name>openmap_1_county_default</name><workspace>OpenMap</workspace></defaultStyle></layer>" http://localhost:8080/geoserver/rest/layers/county
        call_rest("put", "#{BASE_URL}/layers/county",
                         "<layer>
                            <defaultStyle>
                              <name>#{sname}</name>
                              <workspace>#{GEOSERVER_WORKSPACE}</workspace>
                            </defaultStyle>
                          </layer>")

        # Need to create the a style for each individual county in order to display just that county
        # One style per county
        counties.each do |county|
            xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
                <sld:StyledLayerDescriptor xmlns=\"http://www.opengis.net/sld\" xmlns:sld=\"http://www.opengis.net/sld\" xmlns:ogc=\"http://www.opengis.net/ogc\" xmlns:gml=\"http://www.opengis.net/gml\" version=\"1.0.0\">
                  <sld:NamedLayer>
                    <sld:Name>openmap_#{map.id}_county_#{county.id}_map</sld:Name>
                    <sld:UserStyle>
                      <sld:Name>openmap_#{map.id}_county_#{county.id}_map</sld:Name>
                      <sld:Title>A county style</sld:Title>
                      <sld:IsDefault>0</sld:IsDefault>
                      <sld:FeatureTypeStyle>
                        <sld:Name>name</sld:Name>
                        <sld:Rule>
                        <ogc:Filter>
                        <ogc:PropertyIsEqualTo>
                            <ogc:PropertyName>gid</ogc:PropertyName>
                            <ogc:Literal>#{county.gid}</ogc:Literal>
                        </ogc:PropertyIsEqualTo>
                        </ogc:Filter>
                        <sld:Title>cyan polygon</sld:Title>
                          <sld:PolygonSymbolizer>
                            <sld:Stroke>
                              <sld:CssParameter name=\"stroke-opacity\">0.36</sld:CssParameter>
                            </sld:Stroke>
                          </sld:PolygonSymbolizer>
                          <sld:TextSymbolizer>
                            <sld:Label>
                              <ogc:PropertyName>name</ogc:PropertyName>
                            </sld:Label>
                            <sld:Font>
                              <sld:CssParameter name=\"font-family\">Verdana</sld:CssParameter>
                              <sld:CssParameter name=\"font-size\">12</sld:CssParameter>
                              <sld:CssParameter name=\"font-style\">normal</sld:CssParameter>
                              <sld:CssParameter name=\"font-weight\">bold</sld:CssParameter>
                            </sld:Font>
                            <sld:LabelPlacement>
                              <sld:PointPlacement>
                                <sld:AnchorPoint>
                                  <sld:AnchorPointX>0.0</sld:AnchorPointX>
                                  <sld:AnchorPointY>0.5</sld:AnchorPointY>
                                </sld:AnchorPoint>
                              </sld:PointPlacement>
                            </sld:LabelPlacement>
                            <sld:Halo>
                              <sld:Radius>2</sld:Radius>
                              <sld:Fill>
                                <sld:CssParameter name=\"fill\">#FFFFFF</sld:CssParameter>
                              </sld:Fill>
                            </sld:Halo>
                          </sld:TextSymbolizer>
                        </sld:Rule>
                      </sld:FeatureTypeStyle>
                    </sld:UserStyle>
                  </sld:NamedLayer>
                </sld:StyledLayerDescriptor>"

            call_rest(:post, "#{BASE_URL_WORKSPACE}/styles", xml, 'application/vnd.ogc.sld+xml')
        end

        # Create zip code layer
        puts "Creating Geoserver zip_code featuretypes..."
        call_rest(:post, "#{BASE_URL}/workspaces/#{GEOSERVER_WORKSPACE}/datastores/#{GEOSERVER_DATASTORE}/featuretypes",
                            "<featureType>
                                <name>zip_code</name>
                            </featureType>")

        # Create zip code styles
        # Default style will filter all zip codes intersected by the map geometry
        # Because zip codes do not strictly follow state lines part of
        # a zip code may be outside of the state

        xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
                <sld:StyledLayerDescriptor xmlns=\"http://www.opengis.net/sld\" xmlns:sld=\"http://www.opengis.net/sld\" xmlns:ogc=\"http://www.opengis.net/ogc\" xmlns:gml=\"http://www.opengis.net/gml\" version=\"1.0.0\">
                  <sld:NamedLayer>
                    <sld:Name>openmap_#{map.id}_zip_default</sld:Name>
                    <sld:UserStyle>
                      <sld:Name>openmap_#{map.id}_zip_default</sld:Name>
                      <sld:Title>Blank style for zip codes</sld:Title>
                      <sld:IsDefault>1</sld:IsDefault>
                      <sld:FeatureTypeStyle>
                        <sld:Name>name</sld:Name>
                        <sld:Rule>
                          <sld:Title>blank</sld:Title>
                          <sld:PolygonSymbolizer/>
                        </sld:Rule>
                      </sld:FeatureTypeStyle>
                    </sld:UserStyle>
                  </sld:NamedLayer>
                </sld:StyledLayerDescriptor>"

        call_rest(:post, "#{BASE_URL_WORKSPACE}/styles", xml, 'application/vnd.ogc.sld+xml')

        # set the default style
        call_rest(:put, "#{BASE_URL}/layers/zip_code",
                         "<layer>
                             <defaultStyle>
                                 <name>openmap_#{map.id}_zip_default</name>
                                 <workspace>#{GEOSERVER_WORKSPACE}</workspace>
                             </defaultStyle>
                         </layer>")

        # Select zip codes inside the state
        zip_codes = ZipCode.intersects_map(map).select(:gid, :id)

        zip_codes.each do |zip_code|
            xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
                    <sld:StyledLayerDescriptor xmlns=\"http://www.opengis.net/sld\" xmlns:sld=\"http://www.opengis.net/sld\" xmlns:ogc=\"http://www.opengis.net/ogc\" xmlns:gml=\"http://www.opengis.net/gml\" version=\"1.0.0\">
                      <sld:NamedLayer>
                        <sld:Name>openmap_#{map.id}_zip_#{zip_code.id}_map</sld:Name>
                        <sld:UserStyle>
                          <sld:Name>openmap_#{map.id}_zip_#{zip_code.id}_map</sld:Name>
                          <sld:FeatureTypeStyle>
                            <sld:Name>name</sld:Name>
                            <sld:Rule>
                              <ogc:Filter>
                                <ogc:PropertyIsEqualTo>
                                  <ogc:PropertyName>gid</ogc:PropertyName>
                                  <ogc:Literal>#{zip_code.gid}</ogc:Literal>
                                </ogc:PropertyIsEqualTo>
                              </ogc:Filter>
                              <sld:PolygonSymbolizer>
                                <sld:Fill>
                                  <sld:CssParameter name=\"fill-opacity\">0.21</sld:CssParameter>
                                </sld:Fill>
                                <sld:Stroke>
                                  <sld:CssParameter name=\"stroke-width\">2</sld:CssParameter>
                                </sld:Stroke>
                              </sld:PolygonSymbolizer>
                              <sld:TextSymbolizer>
                                <sld:Label>
                                  <ogc:PropertyName>name</ogc:PropertyName>
                                </sld:Label>
                                <sld:Font>
                                  <sld:CssParameter name=\"font-family\">Verdana</sld:CssParameter>
                                  <sld:CssParameter name=\"font-size\">12</sld:CssParameter>
                                  <sld:CssParameter name=\"font-style\">normal</sld:CssParameter>
                                  <sld:CssParameter name=\"font-weight\">normal</sld:CssParameter>
                                </sld:Font>
                                <sld:LabelPlacement>
                                  <sld:PointPlacement>
                                    <sld:AnchorPoint>
                                      <sld:AnchorPointX>0.0</sld:AnchorPointX>
                                      <sld:AnchorPointY>0.5</sld:AnchorPointY>
                                    </sld:AnchorPoint>
                                  </sld:PointPlacement>
                                </sld:LabelPlacement>
                              </sld:TextSymbolizer>
                            </sld:Rule>
                          </sld:FeatureTypeStyle>
                        </sld:UserStyle>
                      </sld:NamedLayer>
                    </sld:StyledLayerDescriptor>"

            call_rest(:post, "#{BASE_URL_WORKSPACE}/styles", xml, 'application/vnd.ogc.sld+xml')
        end


        # Create District layer
        puts "Creating Geoserver district featuretypes..."
        call_rest(:post, "#{BASE_URL}/workspaces/#{GEOSERVER_WORKSPACE}/datastores/#{GEOSERVER_DATASTORE}/featuretypes",
                          "<featureType>
                             <name>district</name>
                           </featureType>")

        # Create district styles
        # Default style will filter all district intersected by the map geometry
        xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
                <sld:StyledLayerDescriptor xmlns=\"http://www.opengis.net/sld\" xmlns:sld=\"http://www.opengis.net/sld\" xmlns:ogc=\"http://www.opengis.net/ogc\" xmlns:gml=\"http://www.opengis.net/gml\" version=\"1.0.0\">
                  <sld:NamedLayer>
                    <sld:Name>openmap_#{map.id}_district_default</sld:Name>
                    <sld:UserStyle>
                      <sld:Name>openmap_#{map.id}_district_default</sld:Name>
                      <sld:IsDefault>1</sld:IsDefault>
                      <sld:FeatureTypeStyle>
                        <sld:Name>name</sld:Name>
                        <sld:Rule>
                          <sld:PolygonSymbolizer/>
                        </sld:Rule>
                      </sld:FeatureTypeStyle>
                    </sld:UserStyle>
                  </sld:NamedLayer>
                </sld:StyledLayerDescriptor>"

        # create the style
        call_rest(:post, "#{BASE_URL_WORKSPACE}/styles", xml, 'application/vnd.ogc.sld+xml')

        # set it as default
        call_rest(:put, "#{BASE_URL}/layers/district",
                         "<layer>
                             <defaultStyle>
                                 <name>openmap_#{map.id}_district_default</name>
                                 <workspace>#{GEOSERVER_WORKSPACE}</workspace>
                             </defaultStyle>
                          </layer>")

        # Select district inside the state
        districts = District.intersects_map(map).select(:gid, :id)

        districts.each do |district|
            xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
                    <sld:StyledLayerDescriptor xmlns=\"http://www.opengis.net/sld\" xmlns:sld=\"http://www.opengis.net/sld\" xmlns:ogc=\"http://www.opengis.net/ogc\" xmlns:gml=\"http://www.opengis.net/gml\" version=\"1.0.0\">
                      <sld:NamedLayer>
                        <sld:Name>openmap_#{map.id}_district_#{district.id}_map</sld:Name>
                        <sld:UserStyle>
                          <sld:Name>openmap_#{map.id}_district_#{district.id}_map</sld:Name>
                          <sld:FeatureTypeStyle>
                            <sld:Name>name</sld:Name>
                            <sld:Rule>
                              <ogc:Filter>
                                <ogc:PropertyIsEqualTo>
                                  <ogc:PropertyName>gid</ogc:PropertyName>
                                  <ogc:Literal>#{district.gid}</ogc:Literal>
                                </ogc:PropertyIsEqualTo>
                              </ogc:Filter>
                              <sld:PolygonSymbolizer>
                                <sld:Fill>
                                  <sld:CssParameter name=\"fill-opacity\">0.21</sld:CssParameter>
                                </sld:Fill>
                                <sld:Stroke>
                                  <sld:CssParameter name=\"stroke-width\">2</sld:CssParameter>
                                </sld:Stroke>
                              </sld:PolygonSymbolizer>
                              <sld:TextSymbolizer>
                                <sld:Label>
                                  <ogc:PropertyName>name</ogc:PropertyName>
                                </sld:Label>
                                <sld:Font>
                                  <sld:CssParameter name=\"font-family\">Verdana</sld:CssParameter>
                                  <sld:CssParameter name=\"font-size\">12</sld:CssParameter>
                                  <sld:CssParameter name=\"font-style\">normal</sld:CssParameter>
                                  <sld:CssParameter name=\"font-weight\">normal</sld:CssParameter>
                                </sld:Font>
                                <sld:LabelPlacement>
                                  <sld:PointPlacement>
                                    <sld:AnchorPoint>
                                      <sld:AnchorPointX>0.0</sld:AnchorPointX>
                                      <sld:AnchorPointY>0.5</sld:AnchorPointY>
                                    </sld:AnchorPoint>
                                  </sld:PointPlacement>
                                </sld:LabelPlacement>
                              </sld:TextSymbolizer>
                            </sld:Rule>
                          </sld:FeatureTypeStyle>
                        </sld:UserStyle>
                      </sld:NamedLayer>
                    </sld:StyledLayerDescriptor>"

            call_rest(:post, "#{BASE_URL_WORKSPACE}/styles", xml, 'application/vnd.ogc.sld+xml')
        end

    end        # task configure_geoserver


    # wrapper for REST calls to place in a begin rescue block
    def call_rest(verb, url, xml=nil, content_type='text/xml')
        begin
            case verb.to_sym
            when :get
                RestClient.get(url)
            when :post
                RestClient.post(url, xml, :content_type => content_type)
            when :put
                RestClient.put(url, xml, :content_type => content_type)
            when :delete
                RestClient.delete(url)
            end
        rescue => e
            puts "Exception at: #{url}"
            puts e.response ? e.response : e
        end
    end

    def psql_command
        database_config = Rails.configuration.database_configuration[Rails.env]
        "#{PSQL} -h #{database_config["host"]} -p #{database_config["port"] || '5432'} -d #{database_config["database"]} -U #{database_config["username"]}"
    end

    def psql_password
        Rails.configuration.database_configuration[Rails.env]["password"]
    end

end


# Test case to see which counties are instersected by the union of the provider_services
# CREATE MATERIALIZED VIEW county_test AS
# SELECT name, geometry
# FROM county
# WHERE ST_INTERSECTS(ST_UNION(ARRAY(SELECT geometry FROM provider_service)), county.geometry)


# # Should fix any ring self intersections in the provider_service table
# # After that it will be safe to union the provider_services into a map geometry
# UPDATE provider_service AS c
# SET geometry = ST_MakeValid(c.geometry) WHERE ST_IsValid(c.geometry) = false;

# Create map geometry as a union of all provider_service geometry
# UPDATE map AS m
# SET geometry = ST_UNION(ARRAY(SELECT geometry FROM provider_service))

# UPDATE map AS m
# SET geometry = ST_UNION(ARRAY(SELECT geometry FROM county WHERE NAME IN ('Pender', 'Onslow', 'Nash', 'Wake', 'Durham')));
