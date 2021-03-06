// REQUIRE/IMPORT LIBRARIES
var app = require('express')(),
  express = require('express'),
  flash = require('connect-flash'),
  http = require('http').Server(app),
  bodyParser = require('body-parser'),
  morgan = require('morgan'),
  mysql = require('mysql'),
  mongodb = require('mongodb'),
  mongoose = require('mongoose'),
  session = require('express-session'),
  io = require('socket.io')(http),
  bcrypt = require('bcrypt'),
  r = require('rethinkdb'),
  jwt = require('jsonwebtoken'),
  dotenv = require('dotenv');


// CONNECT TO ReThinkDB
  var rethinkdb = null;
  r.connect({host: 'localhost', port: 28015, db: 'peer2package'}, function (err, conn) {
    if (err) throw err;
    rethinkdb = conn;
  });

// CONNECT TO MongoDB
mongoose.connect('mongodb://localhost/peer2package');

var Location = mongoose.model('Location', {email: String, lng: Number, lat: Number});

// IMPORT VARIABLES FROM .ENV FILE
dotenv.load();

// BCRYPT PASSWORD HASHING
const salt = process.env.BCRYPT_SALT;
//const salt = bcrypt.genSaltSync(10);

var lng = '';
var lat = '';
var uname = '';
var email = '';
var fname = '';
var lname = '';
var location = null;
var myPosition = '';
var generatedKeys = ''

// DEFINE A PORT WE WANT TO USE
const PORT=8000;

// LOAD IN ENVIRONMENT VARIABLES
const secret = process.env.JWT_SECRET;

// CONFIGURE MYSQL
var connection = mysql.createConnection({
  host: 'localhost',
  user: 'root',
  password: '',
  database: 'peer2package'
});
connection.connect();

// CONFIGURE APP
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static(__dirname + '/public'));
app.use(flash());
app.use(function(req, res, next) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST');
    res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With,content-type, Authorization');
    next();
});
app.use(session({
  secret: 'sssshhhhhhhhhhhhhhh!',
  resave: true,
  saveUninitialized: false,
  cookie: {
    secure: true
  }
}));
app.use(morgan('dev'));

function ensureAuthorized(req, res, next) {
  var bearerToken
  var bearerHeader = req.headers["authorization"]
  if (typeof bearerHeader !== 'undefined') {
    var bearer = bearerHeader.split(" ")
    bearerToken = bearer[1]
    req.token = bearerToken
    next()
  } else {
    res.send(403)
  }
}

// CONFIGURE ROUTES
app.get('/', function (req, res) {
    res.sendFile('index.html');
});

app.post('/register', function (req, res) {
  var user = req.body;
  var hash = bcrypt.hashSync(user.pword, salt);
  user.pword = hash;
  delete user.password;
  var insertQuery = 'SELECT * FROM users WHERE email="'+user.email+'";';
  connection.query(insertQuery, function(err, rows) {
    if (err) {
      res.send(err);
    }
    if (rows.length) {
        res.send({message: 'That email is already in use!'});
    } else {
      var newQuery = 'INSERT INTO users (email, fname, lname, pword) VALUES ("'+user.email+'","'+user.fname+'","'+user.lname+'","'+user.pword+'");';
      connection.query(newQuery, function(err, rows) {
        console.log('Registration successful!');
        user.token = jwt.sign(user, process.env.JWT_SECRET);
        uname = user.fname + ' ' + user.lname;
        email = user.email;
        fname = user.fname;
        lname = user.lname;
        res.send({
          user: {
            email: user.email,
            fname: user.fname,
            lname: user.lname
          },
          token: user.token
        });
      })
    }
  })
});

app.post('/login', function (req, res) {
  var testUser = req.body
  var user = {}
  var hash = bcrypt.hashSync(testUser.password, salt);
  testUser.password = hash;
  var insertQuery = 'SELECT * FROM users WHERE email="'+testUser.email+'";';
  connection.query(insertQuery, function(err, rows) {
    if (err) throw err;
    if (rows.length) {
      if (rows[0].pword === testUser.password) {
        console.log('User logged in successfully!');
        user.token = jwt.sign(user, process.env.JWT_SECRET);
        uname = rows[0].fname + ' ' + rows[0].lname
        email = rows[0].email
        fname = rows[0].fname
        lname = rows[0].lname
        res.send({
          user: {
            id: rows[0].id,
            email: rows[0].email,
            fname: rows[0].fname,
            lname: rows[0].lname
          },
          token: user.token
        });
      } else {
        console.log('The password is incorrect.')
        res.send({message: 'The password is incorrect!'})
      }
    } else {
      console.log('That email does not exist.')
      res.send({message: 'That email does not exist.'})
    }
  })
});

app.post('/delete', function (req, res) {
  var user = req.body
  var insertQuery = 'DELETE FROM users WHERE id="' + user.id + '";'
  connection.query(insertQuery, function (err, rows) {
    if (err) throw err;
    if (rows.length) {
      console.log('User deleted');
      res.send({
        message: 'User deleted.'
      })
    }
  })
});


app.get('/map', function (req, res) {
  res.sendFile(__dirname + '/public/map.html');
});

app.get('/other_positions', function (req, res) {
  r.table('locations').get(generatedKeys).run(rethinkdb, function(err, result) {
    if (err) throw err;
    if (result) {
      lng = result.lng;
      lat = result.lat;
    }
  })
  console.log('longitude:' + lng + ', latitude:' + lat);
});

app.get('/user_location', function (req, res) {
  r.table('locations').get(generatedKeys).run(rethinkdb, function(err, result) {
    if (err) throw err;
    if (result) {
      lng = result.lng;
      lat = result.lat;
    }
  })

  res.send({
    "geometry": {
      "type": "Point",
      "coordinates": [ lng, lat ]
    },
    "type": "Feature",
    "properties": {
      "title": "You",
      "description": "<style>div.profile > img{height:70px;width:70px;}div.mapboxgl-popup {padding:10px;width:50%;background-color:#1C283B;border-radius:4px;margin-top:-80px;align-self:flex-start;}div.profile > span#userName{margin-right:10px}</style><div class='profile'><img src='../img/profile.gif' /><span#userName> " + uname + " </h1></div>"
    }
  });
});

// SOCKET.IO
io.on('connection', function (socket) {
  console.log('A user has connected');
  socket.on('LngLat', function (yourPosition) {
    myPosition = yourPosition.split(',');
    r.table('locations').insert({
        lng: myPosition[0],
        lat: myPosition[1]
    }).run(rethinkdb).then(function (response) {
      var genKey = JSON.stringify(response.generated_keys).replace(/[[\]]/g,'');
      generatedKeys = genKey.replace(/"/g, '');
    }).error(function (err) {
      console.log('error occured', err);
    });
  });
  socket.on('chat message', function (message) {
    console.log(uname + ': ' + message.message)
    io.emit('chat message', message.message)
  })
  socket.on('disconnect', function () {
    console.log('A user has disconnected');
  })
});

// SERVER
http.listen(PORT, function () {
  console.log('Listening on port ' + PORT);
});
