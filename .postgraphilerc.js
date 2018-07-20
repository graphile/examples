const PgSimplifyInflectorPlugin = require("@graphile-contrib/pg-simplify-inflector");

['AUTH_DATABASE_URL', 'NODE_ENV'].forEach(envvar => {
  if (!process.env[envvar]) {
    // We automatically source `.env` in the various scripts; but in case that
    // hasn't been done lets raise an error and stop.
    console.error("");
    console.error("");
    console.error("⚠️⚠️⚠️⚠️");
    console.error(`No ${envvar} found in your environment; perhaps you need to run 'source ./.env'?`);
    console.error("⚠️⚠️⚠️⚠️");
    console.error("");
    process.exit(1);
  }
});

const isDev = process.env.NODE_ENV === "development";

// Our database URL
const connection = process.env.AUTH_DATABASE_URL;
// The PostgreSQL schema within our postgres DB to expose
const schema = ["app_public"];
// Enable GraphiQL interface
const graphiql = true;
// Send back JSON objects rather than JSON strings
const dynamicJson = true;
// Watch the database for changes
const watch = true;
// Add some Graphile-Build plugins to enhance our GraphQL schema
const appendPlugins = [
  // Removes the 'ByFooIdAndBarId' from the end of relations
  PgSimplifyInflectorPlugin,
];

module.exports = {
  // Config for the library (middleware):
  library: {
    connection,
    schema,
    options: {
      dynamicJson,
      graphiql,
      watchPg: watch,
      appendPlugins,
    },
  },
  // Options for the CLI:
  options: {
    connection,
    schema,
    dynamicJson,
    disableGraphiql: !graphiql,
    // We don't set a watch mode here, because there's no way to turn it off (e.g. when using -X) currently.
    appendPlugins,
  },
};
