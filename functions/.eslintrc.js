module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    // Let us use single or double quotes
    "quotes": "off",

    // Windows line endings are fine
    "linebreak-style": "off",

    // Keep long lines as warnings (140 chars)
    "max-len": ["warn", { "code": 140, "ignoreUrls": true }],

    // Turn off strict style nits that were throwing hundreds of errors
    "object-curly-spacing": "off",
    "one-var": "off",
    "arrow-parens": "off",
    "operator-linebreak": "off",
    "brace-style": ["warn", "1tbs", { "allowSingleLine": true }],
    "no-multi-spaces": "off",
    "comma-dangle": "off",
    "require-jsdoc": "off",

    // TS-specific relaxations
    "@typescript-eslint/no-unused-vars": ["warn"],
    "@typescript-eslint/no-non-null-assertion": "off",

    // Keep your indent rule if you like
    "indent": ["error", 2],

    // Keep import resolver disabled as you already had
    "import/no-unresolved": 0

  },
};
