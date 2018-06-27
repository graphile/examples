const fs = require("fs");

const middlewares = fs
  .readdirSync(__dirname)
  .filter(fn => fn !== "index.js")
  .filter(fn => fn.match(/^[^.].*\.js$/))
  .map(str => str.substr(0, str.length - 3));

middlewares.forEach(name => {
  // eslint-disable-next-line import/no-dynamic-require
  exports[name] = require(`./${name}`);
});
