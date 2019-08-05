# Generated Data

Normally you wouldn't track generated data in git; however we deliberately keep these resources under version control:

- `schema.graphql` is compared during upgrades, migrations and pull requests so you can see what has changed and ensure there’s no accidental GraphQL regressions
- `schema.sql` is kept for similar (but database) reasons, and to ensure that all developers are running the same version of the database without accidental differences caused by faulty migration hygeine
- `schema.json` is used by various tooling (e.g. ESLint) to validate the GraphQL queries; technically we should probably just use schema.graphql for this 🤷‍♂️
