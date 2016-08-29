peer2package = angular.module 'peer2package', ['ui.router', 'ngStorage', 'ngGeolocation']

peer2package.config ($stateProvider, $urlRouterProvider) ->
  $stateProvider
    .state 'main', {templateUrl: 'home.html', controller: 'mainController'}
    .state 'account', {templateUrl: 'account.html', controller: 'accountController'}
    .state 'map', {templateUrl: 'map.html', controller: 'mapController'}
    .state 'map2', {templateUrl: 'map2.html', controller: 'mapController'}
    .state 'photoUpload', {templateUrl: 'photo_upload.html', controller: 'photoController'}
    .state 'gps', {templateUrl: 'gps.html', controller: 'gpsController'}

peer2package.controller 'mainController', ($scope, $localStorage) ->
  if $localStorage.token
    $scope.token = $localStorage.token

peer2package.factory 'userService', ($http) ->
  currentUser = {}
  return {
    login: (user) ->
      $postedUser = $http.post('/login', user)
      $postedUser.then((response) ->
        currentUser = response.data.user
        console.log currentUser
      )
      return $postedUser

    register: (user) ->
      $postedUser = $http.post('/register', user)
      $postedUser.then((response) ->
        currentUser = response.data.user
      )
      return $postedUser

    delete: (user) ->
      $postedUser = $http.post('/delete', user)
      $postedUser.then((response) ->
        currentUser = ''
      )
    logout: () ->

    isLoggedIn: () ->

    currentUser: () ->
      return currentUser
  }

peer2package.controller 'menuController', ['$scope', '$http', '$localStorage', 'userService', ($scope, $http, $localStorage, userService) ->
  $scope.message = null
  menu = document.getElementById 'menu'
  arrow = document.getElementById 'arrow'
  btn_logout = document.getElementById 'logout'
  btn_home = document.getElementById 'home'
  menubox = document.getElementById 'menubox'
  sidenavmenu = document.getElementById 'side-nav-menu'

  $scope.loggedIn = () ->
    menubox.classList.add 'loggedIn'

  $scope.submitReg = (user) ->
    userService.register(user).then((response) ->
      btn_home.classList.add 'active'
      arrow.classList.remove 'logoout'
      btn_logout.classList.remove 'active'
      $scope.token = response.data.token || null
      $scope.messageReg = response.data.message
      if (response.data.token)
        $localStorage.token = response.data.token
        $scope.loggedIn()
      )
  $scope.submitLog = (user) ->
    userService.login(user).then((response) ->
      btn_home.classList.add 'active'
      arrow.classList.remove 'logout'
      btn_logout.classList.remove 'active'
      $scope.token = response.data.token || null
      $scope.messageLog = response.data.message
      if (response.data.token)
        $localStorage.token = response.data.token
        $scope.loggedIn()
      )

  $scope.logout = () ->
    $scope.regForm.user = {}
    $scope.loginForm.user = {}
    menubox.classList.remove 'loggedIn'
    $localStorage.$reset()
    setTimeout ->
      menu.classList.toggle 'open'
      sidenavmenu.classList.toggle 'nav-open'
    , 500
]

peer2package.service 'mapService', ['$rootScope', '$geolocation', 'socket', '$interval', ($rootScope, $geolocation, socket, $interval) ->
  $rootScope.loading = true
  longitude = null
  latitude = null
  $rootScope.$on('$viewContentLoaded', () ->
    $geolocation.getCurrentPosition({
      timeout: 60000
    })
    .then (position) ->
      longitude = position.coords.longitude
      latitude = position.coords.latitude
      $rootScope.myPosition = position
      $interval (->
        $geolocation.getCurrentPosition(timeout: 60000).then (position) ->
          $rootScope.myPosition = position
          longitude = position.coords.longitude
          latitude = position.coords.latitude
          return
        return
      ), 1000
      $rootScope.$watch('myPosition.coords', (newValue, oldValue) ->
        longitude = newValue.longitude
        latitude = newValue.latitude
        url = 'http://localhost:8000/user_location'
        yourPosition = longitude + ', ' + latitude
        source.setData(url)
        socket.emit 'LngLat', yourPosition
      )
      mapboxgl.accessToken = 'pk.eyJ1IjoiamFtZXNhZGlja2Vyc29uIiwiYSI6ImNpbmNidGJqMzBwYzZ2OGtxbXljY3FrNGwifQ.5pIvQjtuO31x4OZm84xycw'
      map = new mapboxgl.Map({
        container: 'map',
        style: 'mapbox://styles/jamesadickerson/ciq1h3u9r0009b1lx99e6eujf',
        zoom: 19
      })
      url = 'http://localhost:8000/user_location'
      source = new mapboxgl.GeoJSONSource {data:url}
      map.on 'load', () ->
        $rootScope.loading = false
        map.addSource 'You', source
        map.addLayer({
          "id": "You",
          "type": "circle",
          "source": "You",
          "paint": {
            "circle-radius": 20,
            "circle-color": "#E65D5D"
          }
        })
        map.setCenter([longitude, latitude])
        console.log(longitude + ',' + latitude)
        map.on 'click', (e) ->
          features = map.queryRenderedFeatures e.point, {layers:['You']}
          if (!features.length)
            return
          feature = features[0]
          popup = new mapboxgl.Popup({closeButton:false}).setLngLat([longitude, latitude]).setHTML(feature.properties.description).addTo(map)


    moveCenter = () ->
      return map.flyTo {center:[longitude,latitude]}


  )
]

peer2package.controller 'mapController', ['$scope', 'mapService', 'socket', ($scope, mapService, socket) ->
  $scope.moveToPosition = () ->
    mapService.moveCenter()

  $scope.chat_open = false

  $scope.open_chat = () ->
    $scope.chat_open = true

  $scope.close_chat = () ->
    $scope.chat_open = false
  $scope.submitChat = (message) ->
    socket.emit 'chat message', {
      message: message
    }
    $scope.sent = message
    $scope.message = ''
  socket.on 'chat message', (message) ->
    messagelist = angular.element(document.querySelector('#messages'))
    messagelist.append('<li>' + message + '</li>')

]

peer2package.service 'gpsService', ['$rootScope', '$geolocation', ($rootScope, $geolocation) ->
  longitude = null
  latitude = null
  $rootScope.$on('$viewContentLoaded', () ->
    $geolocation.getCurrentPosition({
      timeout: 60000
    })
    .then (position) ->
      $rootScope.myPosition = position
      $geolocation.watchPosition({
        timeout: 60000,
        maximumAge: 250,
        enableHighAccuracy: true
      })
      $rootScope.myPosition = $geolocation.position
      $rootScope.$watch('myPosition.coords', (newValue, oldValue) ->
        $rootScope.longitude = newValue.longitude
        longitude = $rootScope.longitude
        $rootScope.latitude = newValue.latitude
        latitude = $rootScope.latitude
        map.setCenter([$rootScope.longitude, $rootScope.latitude])
      )
      $rootScope.loading = false
    mapboxgl.accessToken = 'pk.eyJ1IjoiamFtZXNhZGlja2Vyc29uIiwiYSI6ImNpbmNidGJqMzBwYzZ2OGtxbXljY3FrNGwifQ.5pIvQjtuO31x4OZm84xycw'
    map = new mapboxgl.Map({
      container: 'map',
      style: 'mapbox://styles/jamesadickerson/ciq1h3u9r0009b1lx99e6eujf',
      zoom: 19,
      pitch: 45
    })
    map.addControl(new mapboxgl.Directions())
    map.setCenter([longitude, latitude])
  )
]

peer2package.controller 'gpsController', ['$scope', 'gpsService', ($scope, gpsService) ->
]

peer2package.directive 'loading', ['$http', '$rootScope', ($http, $rootScope) ->
  return {
    restrict: 'A',
    link: (scope, element, attributes) ->
      scope.isLoading = () ->
        return $http.pendingRequests.length > 0
      scope.$watch(scope.isLoading, (value) ->
        if (value)
          element.removeClass('hidden')
        else
          element.addClass('hidden')
      )
  }
]


peer2package.controller 'accountController', ['$scope', 'userService', '$location', ($scope, userService, $location) ->
  $scope.currentUser = userService.currentUser()
  $scope.name = $scope.currentUser.fname + ' ' + $scope.currentUser.lname
  $scope.balance = 0.00
  $scope.deleteAccount = (user) ->
    userService.delete(user).then((response) ->
      $localStorage.$reset()
      $location.path '/'
    )

]

peer2package.controller 'photoController', ($scope) ->

peer2package.factory 'socket', ($rootScope) ->
  socket = io.connect()
  {
    on: (eventName, callback) ->
      socket.on eventName, ->
        args = arguments
        $rootScope.$apply ->
          callback.apply socket, args
          return
        return
      return
    emit: (eventName, data, callback) ->
      socket.emit eventName, data, ->
        args = arguments
        $rootScope.$apply ->
          if callback
            callback.apply socket, args
          return
        return
      return
  }

peer2package.directive 'menuChange', () ->
  return {
    restrict: 'AE',
    link: () ->
      menu = document.getElementById 'menu'
      sidenavmenu = document.getElementById 'side-nav-menu'
      arrow = document.getElementById 'arrow'
      btn_home = document.getElementById 'home'
      btn_account = document.getElementById 'account'
      btn_map = document.getElementById 'gps'
      btn_logout = document.getElementById 'logout'

      menu.addEventListener 'click', () ->
        menu.classList.toggle 'open'
        sidenavmenu.classList.toggle 'nav-open'


      btn_account.addEventListener 'click', () ->
        arrow.classList.add 'account'
        arrow.classList.remove 'home'
        arrow.classList.remove 'map'
        arrow.classList.remove 'logout'
        btn_account.classList.add 'active'
        btn_home.classList.remove 'active'
        btn_map.classList.remove 'active'
        btn_logout.classList.remove 'active'
        setTimeout ->
          menu.classList.toggle 'open'
          sidenavmenu.classList.toggle 'nav-open'
        , 500

      btn_home.addEventListener 'click', () ->
        arrow.classList.add 'home'
        arrow.classList.remove 'account'
        arrow.classList.remove 'map'
        arrow.classList.remove 'logout'
        btn_home.classList.add 'active'
        btn_account.classList.remove 'active'
        btn_map.classList.remove 'active'
        btn_logout.classList.remove 'active'
        setTimeout ->
          menu.classList.toggle 'open'
          sidenavmenu.classList.toggle 'nav-open'
        , 500

      btn_map.addEventListener 'click', () ->
        arrow.classList.add 'map'
        arrow.classList.remove 'account'
        arrow.classList.remove 'home'
        arrow.classList.remove 'logout'
        btn_map.classList.add 'active'
        btn_home.classList.remove 'active'
        btn_account.classList.remove 'active'
        btn_logout.classList.remove 'active'
        setTimeout ->
          menu.classList.toggle 'open'
          sidenavmenu.classList.toggle 'nav-open'
        , 500

      btn_logout.addEventListener 'click', () ->
        arrow.classList.add 'logout'
        arrow.classList.remove 'map'
        arrow.classList.remove 'account'
        arrow.classList.remove 'home'
        btn_logout.classList.add 'active'
        btn_map.classList.remove 'active'
        btn_home.classList.remove 'active'
        btn_account.classList.remove 'active'

  }
