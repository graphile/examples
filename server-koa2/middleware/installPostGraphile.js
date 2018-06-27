const { postgraphile } = require("postgraphile");
const PgSimplifyInflectorPlugin = require("@graphile-contrib/pg-simplify-inflector");

const isDev = process.env.NODE_ENV === "development";

module.exports = function installPostGraphile(app) {
  app.use((ctx, next) => {
    // PostGraphile deals with (req, res) but we want access to sessions from `pgSettings`, so we make the ctx available on req.
    ctx.req.ctx = ctx;
    return next();
  });

  app.use(
    postgraphile(process.env.AUTH_DATABASE_URL, "app_public", {
      dynamicJson: true,
      graphiql: true,
      watchPg: isDev,
      appendPlugins: [PgSimplifyInflectorPlugin],
      pgSettings(req) {
        return {
          role: "graphiledemo_visitor",
          "jwt.claims.user_id": req.ctx.state.user && req.ctx.state.user.id,
        };
      },
    })
  );
};
