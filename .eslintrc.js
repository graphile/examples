module.exports = {
  parser: "babel-eslint",
  parserOptions: {
    sourceType: "module",
  },
  extends: ["eslint:recommended", "plugin:react/recommended", "prettier"],
  plugins: ["prettier", "graphql", "react"],
  env: {
    browser: true,
    es6: true,
    jest: true,
    node: true,
  },
  rules: {
    "prettier/prettier": [
      "error",
      {
        trailingComma: "es5",
      },
    ],
    "no-unused-vars": [
      2,
      {
        argsIgnorePattern: "^_",
      },
    ],
    "no-console": 0, // This is a demo, so logging console messages can be helpful. Remove this in production!
  },
};
