const koaStatic = require("koa-static");

module.exports = function installSharedStatic(app) {
  app.use(koaStatic(`${__dirname}/../../public`));
};
