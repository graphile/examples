const { makeExtendSchemaPlugin, gql } = require("graphile-utils");

const PassportLoginPlugin = makeExtendSchemaPlugin(build => ({
  typeDefs: gql`
    input LoginInput {
      username: String!
      password: String!
    }
    type LoginPayload {
      user: User! @recurseDataGenerators
    }
    extend type Mutation {
      login(input: LoginInput!): LoginPayload
    }
  `,
  resolvers: {
    Mutation: {
      async login(
        mutation,
        args,
        context,
        resolveInfo,
        { selectGraphQLResultFromTable }
      ) {
        const { username, password } = args.input;
        const { rootPgPool, login } = context;
        try {
          // Call our login function to find out if the username/password combination exists
          const {
            rows: [user],
          } = await rootPgPool.query(
            `select users.* from app_private.login($1, $2) users where users is not null`,
            [username, password]
          );

          if (!user) {
            throw new Error("Login failed");
          }

          // Tell Passport.js we're logged in
          await login(user);

          // Fetch the data that was requested from GraphQL, and return it
          const sql = build.pgSql;
          const [row] = await selectGraphQLResultFromTable(
            sql.fragment`app_public.users`,
            (tableAlias, sqlBuilder) => {
              sqlBuilder.where(
                sql.fragment`${tableAlias}.id = ${sql.value(user.id)}`
              );
            }
          );
          return {
            user: row,
          };
        } catch (e) {
          console.error(e);
          // TODO: check that this is indeed why it failed
          throw new Error("Login failed: incorrect username/password");
        }
      },
    },
  },
}));
module.exports = PassportLoginPlugin;
