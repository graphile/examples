const { postgraphile } = require("postgraphile");
const PassportLoginPlugin = require("../../shared/plugins/PassportLoginPlugin");
const {
  library: { connection, schema, options },
} = require("../../.postgraphilerc.js");

module.exports = function installPostGraphile(app, { rootPgPool }) {
  app.use((ctx, next) => {
    // PostGraphile deals with (req, res) but we want access to sessions from `pgSettings`, so we make the ctx available on req.
    ctx.req.ctx = ctx;
    return next();
  });

  app.use(
    postgraphile(connection, schema, {
      // Import our shared options
      ...options,

      // Since we're using sessions we'll also want our login plugin
      appendPlugins: [
        // All the plugins in our shared config
        ...(options.appendPlugins || []),

        // Adds the `login` mutation to enable users to log in
        PassportLoginPlugin,
      ],

      // Given a request object, returns the settings to set within the
      // Postgres transaction used by GraphQL.
      pgSettings(req) {
        return {
          role: "graphiledemo_visitor",
          "jwt.claims.user_id": req.ctx.state.user && req.ctx.state.user.id,
        };
      },

      // The return value of this is added to `context` - the third argument of
      // GraphQL resolvers. This is useful for our custom plugins.
      additionalGraphQLContextFromRequest(req) {
        return {
          // Let plugins call priviliged methods (e.g. login) if they need to
          rootPgPool,

          // Use this to tell Passport.js we're logged in
          login: user =>
            new Promise((resolve, reject) => {
              req.ctx.login(user, err => (err ? reject(err) : resolve()));
            }),
        };
      },
    })
  );
};
