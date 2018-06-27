module.exports = {
  parser: "babel-eslint",
  parserOptions: {
    sourceType: "module",
  },
  extends: ["eslint:recommended", "plugin:react/recommended", "prettier"],
  plugins: ["prettier", "graphql", "react"],
  env: {
    browser: true,
    node: true,
    es6: true,
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
  },
};
