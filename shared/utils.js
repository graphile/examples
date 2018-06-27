const fs = require("fs");

exports.sanitiseEnv = () => {
  const requiredEnvvars = ["AUTH_DATABASE_URL", "ROOT_DATABASE_URL"];
  requiredEnvvars.forEach(envvar => {
    if (!process.env[envvar]) {
      throw new Error(
        `Could not find process.env.${envvar} - did you remember to run the setup script? Have you sourced the environmental variables file '.env'?`
      );
    }
  });

  process.env.NODE_ENV = process.env.NODE_ENV || "development";
};

exports.installWatchFixtures = rootPgPool => {
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
};
