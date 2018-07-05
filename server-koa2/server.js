const http = require("http");
const Koa = require("koa");
const pg = require("pg");
const sharedUtils = require("../shared/utils");
const middleware = require("./middleware");

sharedUtils.sanitiseEnv();

const rootPgPool = new pg.Pool({
  connectionString: process.env.ROOT_DATABASE_URL,
});

const isDev = process.env.NODE_ENV === "development";

// We're using a non-super-user connection string, so we need to install the
// watch fixtures ourself.
if (isDev) {
  sharedUtils.installWatchFixtures(rootPgPool);
}

const app = new Koa();
const server = http.createServer(app.callback());

middleware.installStandardKoaMiddlewares(app);
middleware.installSession(app);
middleware.installPassport(app, { rootPgPool });
middleware.installPostGraphile(app, { rootPgPool });
middleware.installSharedStatic(app);
middleware.installFrontendServer(app, server);

const PORT = parseInt(process.env.PORT, 10) || 3000;
server.listen(PORT);
console.log(`Listening on port ${PORT}`);
