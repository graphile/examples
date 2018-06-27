const session = require("koa-session");

module.exports = function installSession(app) {
  app.keys = [process.env.SECRET];
  app.use(session({}, app));
};
