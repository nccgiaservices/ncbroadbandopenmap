 // Define the tour!
    var tour = {
      id: "hello-hopscotch",
      showPrevButton: true,
      i18n: {
        prevBtn: "Previous"
      },
      steps: [
        {
          title: "Map",
          content: "This is an interactive map of North Carolina. It is a Google map that you can drag around, and zoom in or out using the plus and minus controls to the left.",
          target: "map_container",
          placement: "top",
          yOffset: 180,
          xOffset: 40,
        },
        {
          title: "Layers",
          content: "The Map Layers section allows you to select various layers on the map. Check a box to show the areas where that service is available.",
          target: "technologies",
          placement: "top",
          xOffset: 10
        },
        {
          title: "Providers",
          content: "This chart will list all of the service providers in an area. In a minute we will see other ways to search for providers.",
          target: "served_providers",
          placement: "right",
          yOffset: 100
        },
        {
          title: "Districts",
          content: "Here you can select from a list of state and federal legislative districts. Clicking on one of them will highlight it on the map and show providers in that area.",
          target: "district_container",
          placement: "bottom",
          xOffset: 10
        },
        {
          title: "Search",
          content: "Here you can search for addresses, zip codes, counties, cities, and other things on the map. Whenever you search for something the list of providers will be updated with results in the area that you searched.",
          target: "address_container",
          placement: "bottom"
        },
        {
          title: "Query Point",
          content: "Clicking this button will allow you to place a marker on the map. The table on the left will show providers from the exact spot that you place the marker.",
          target: "point_query_container",
          placement: "left"
        },
      ]
    };

    // Start the tour!
    // console.log("Starting!");
    // hopscotch.startTour(tour);