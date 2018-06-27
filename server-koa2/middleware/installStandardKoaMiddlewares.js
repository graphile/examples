const helmet = require("koa-helmet");
const cors = require("@koa/cors");
// const jwt = require("koa-jwt");
const compress = require("koa-compress");
const bunyanLogger = require("koa-bunyan-logger");
const bodyParser = require("koa-bodyparser");

module.exports = function installStandardKoaMiddlewares(app) {
  // These middlewares aren't required, I'm using them to check PostGraphile
  // works with Koa.
  app.use(helmet());
  app.use(cors());
  //app.use(jwt({secret: process.env.SECRET}))
  app.use(compress());
  app.use(bunyanLogger());
  app.use(bodyParser());
};
