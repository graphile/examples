const passport = require("koa-passport");
const route = require("koa-route");
const { Strategy: GitHubStrategy } = require("passport-github");
const { Strategy: LocalStrategy } = require("passport-local");

/*
 * This file uses regular Passport.js authentication, both for
 * username/password and for login with GitHub. You can easily add more OAuth
 * providers to this file. For more information, see:
 *
 *   http://www.passportjs.org/
 */

module.exports = function installPassport(app, { rootPgPool }) {
  passport.serializeUser((user, done) => {
    done(null, user.id);
  });

  passport.deserializeUser(async (id, callback) => {
    let error = null;
    let user;
    try {
      const { rows } = await rootPgPool.query(
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
  app.use(passport.initialize());
  app.use(passport.session());

  passport.use(
    new LocalStrategy(async (username, password, done) => {
      let _user;
      let _error;
      try {
        const {
          rows: [user],
        } = await rootPgPool.query(`select * from app_hidden.login($1, $2)`, [
          username,
          password,
        ]);
        _user = user || false;
      } catch (e) {
        _error = e;
      }
      done(_error, _user);
    })
  );

  app.use(
    route.post(
      "/login",
      passport.authenticate("local", { failureRedirect: "/login" }),
      (req, res) => {
        res.redirect("/");
      }
    )
  );

  if (process.env.GITHUB_KEY && process.env.GITHUB_SECRET) {
    passport.use(
      new GitHubStrategy(
        {
          clientID: process.env.GITHUB_KEY,
          clientSecret: process.env.GITHUB_SECRET,
          callbackURL: `${process.env.ROOT_URL}/auth/github/callback`,
          passReqToCallback: true,
        },
        async function(req, accessToken, refreshToken, profile, done) {
          let error;
          let user;
          try {
            const { rows } = await rootPgPool.query(
              `select * from app_private.link_or_register_user($1, $2, $3, $4, $5);`,
              [
                (req.user && req.user.id) || null,
                "github",
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
      )
    );

    app.use(route.get("/auth/github", passport.authenticate("github")));

    app.use(
      route.get(
        "/auth/github/callback",
        passport.authenticate("github", {
          successRedirect: "/",
          failureRedirect: "/login",
        })
      )
    );
  } else {
    console.error(
      "WARNING: you've not set up the GitHub application for login; see `.env` for details"
    );
  }
  app.use(
    route.get("/logout", async ctx => {
      ctx.logout();
      ctx.redirect("/");
    })
  );
};
