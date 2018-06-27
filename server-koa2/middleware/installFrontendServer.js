const httpProxy = require("http-proxy");

module.exports = function installFrontendServer(app, server) {
  const proxy = httpProxy.createProxyServer({
    target: `http://localhost:${process.env.CLIENT_PORT}`,
    ws: true,
  });
  app.use(ctx => {
    // Bypass koa for HTTP proxying
    ctx.respond = false;
    proxy.web(ctx.req, ctx.res, {}, _e => {
      ctx.res.statusCode = 503;
      ctx.res.end(
        "Error occurred while proxying to client application - is it running?"
      );
    });
  });
  server.on("upgrade", (req, socket, head) => {
    proxy.ws(req, socket, head);
  });
};
