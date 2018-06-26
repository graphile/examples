process.env.NODE_ENV = process.env.NODE_ENV || 'development';

const http = require('http');
const fs = require('fs');
const Koa = require('koa');
const { postgraphile } = require('postgraphile');
const session = require('koa-session');
const passport = require('koa-passport');
const route = require('koa-route');
const httpProxy = require('http-proxy');
const { Strategy: GitHubStrategy } = require('passport-github');
const pg = require('pg');

// Unnecessary middlewares to check compatibility
const helmet = require('koa-helmet');
const cors = require('@koa/cors');
const jwt = require('koa-jwt');
const compress = require('koa-compress');
const bunyanLogger = require('koa-bunyan-logger');
const bodyParser = require('koa-bodyparser');

const rootPgPool = new pg.Pool({ connectionString: process.env.ROOT_DATABASE_URL });

passport.serializeUser((user, done) => {
  done(null, user.id);
});

passport.deserializeUser(async (id, callback) => {
  let error = null;
  let user;
  try {
    const {
      rows,
    } = await rootPgPool.query(
      `select users.* from app_public.users where users.id = $1`,
      [id]
    );
    if (!rows.length) {
      user = false;
    } else {
      user = rows[0];
    }
  } catch (e) {
    error = e;
  } finally {
    callback(error, user);
  }
});

const isDev = process.env.NODE_ENV === 'development';

if (isDev) {
  // Install the watch fixtures manually
  const fixtures = fs.readFileSync(
    require.resolve("graphile-build-pg/res/watch-fixtures.sql"),
    "utf8"
  );
  rootPgPool.query(fixtures).then(
    () => {
      console.log(`Loaded watch fixtures ✅`);
      console.log(`Ignore the "Failed to setup watch fixtures" warning`);
    },
    e => {
      console.error("Failed to load watch fixtures 🔥");
      console.error(e);
    }
  );
}
const app = new Koa();

// These middlewares aren't required, I'm using them to check PostGraphile
// works with Koa
app.use(helmet())
app.use(cors())
//app.use(jwt({secret: process.env.SECRET}))
app.use(compress())
app.use(bunyanLogger())
app.use(bodyParser())

app.keys = [process.env.SECRET]
app.use(session({}, app))

app.use(passport.initialize())
app.use(passport.session())

if (process.env.GITHUB_KEY && process.env.GITHUB_SECRET) {
  passport.use(
    new GitHubStrategy({
      clientID: process.env.GITHUB_KEY,
      clientSecret: process.env.GITHUB_SECRET,
      callbackURL: `${process.env.ROOT_URL}/auth/github/callback`,
      passReqToCallback: true,
    },
    async function(req, accessToken, refreshToken, profile, done) {
      let error;
      let user;
      try {
        const {
          rows,
        } = await rootPgPool.query(
          `select * from app_private.link_or_register_user($1, $2, $3, $4, $5);`,
          [
            (req.user && req.user.id) || null,
            'github',
            profile.id,
            JSON.stringify({
              username: profile.username,
              avatar_url: profile._json.avatar_url,
              name: profile.displayName,
            }),
            JSON.stringify({
              accessToken,
              refreshToken,
            }),
          ]
        );
        user = rows[0] || false;
      } catch (e) {
        error = e;
      } finally {
        done(error, user);
      }
    }
  ));

  app.use(route.get('/auth/github',
    passport.authenticate('github')
  ));

  app.use(route.get('/auth/github/callback',
    passport.authenticate('github', {
      successRedirect: '/',
      failureRedirect: '/login'
    })
  ));
} else {
  console.error("WARNING: you've not set up the GitHub application for login; see `.env` for details");
}

app.use(route.get('/logout',
  async ctx => {
    ctx.logout();
    ctx.redirect('/');
  }
));

app.use((ctx, next) => {
  // PostGraphile deals with (req, res) but we want access to sessions, so we make the ctx available on req.
  ctx.req.ctx = ctx;
  return next();
});
app.use(postgraphile(
  process.env.AUTH_DATABASE_URL,
  'app_public',
  {
    dynamicJson: true,
    graphiql: true,
    watchPg: isDev,
    pgSettings(req) {
      return {
        role: 'graphiledemo_visitor',
        "jwt.claims.user_id": req.ctx.state.user && req.ctx.state.user.id,
      };
    },
  }
));

const proxy = httpProxy.createProxyServer({
  target: `http://localhost:${process.env.CLIENT_PORT}`,
  ws: true,
});
app.use((ctx, next) => {
  // Bypass koa for HTTP proxying
  ctx.respond = false;
  proxy.web(ctx.req, ctx.res, {});
});

const server = http.createServer(app.callback());
server.on('upgrade', (req, socket, head) => {
  proxy.ws(req, socket, head);
});

const PORT = parseInt(process.env.PORT, 10) || 3000
server.listen(PORT);
console.log(`Listening on port ${PORT}`);
