const { makeExtendSchemaPlugin, gql } = require("graphile-utils");

const PassportLoginPlugin = makeExtendSchemaPlugin(build => ({
  typeDefs: gql`
    input RegisterInput {
      username: String!
      email: String!
      password: String!
      name: String
      avatarUrl: String
    }

    type RegisterPayload {
      user: User! @recurseDataGenerators
    }

    input LoginInput {
      username: String!
      password: String!
    }

    type LoginPayload {
      user: User! @recurseDataGenerators
    }

    extend type Mutation {
      register(input: RegisterInput!): RegisterPayload
      login(input: LoginInput!): LoginPayload
    }
  `,
  resolvers: {
    Mutation: {
      async register(
        mutation,
        args,
        context,
        resolveInfo,
        { selectGraphQLResultFromTable }
      ) {
        const { username, password, email, name, avatarUrl } = args.input;
        const { rootPgPool, login, pgClient } = context;
        try {
          // Call our login function to find out if the username/password combination exists
          const {
            rows: [user],
          } = await rootPgPool.query(
            `select users.* from app_private.really_create_user(
              username => $1,
              email => $2,
              email_is_verified => false,
              name => $3,
              avatar_url => $4,
              password => $5
            ) users where users is not null`,
            [username, email, name, avatarUrl, password]
          );

          if (!user) {
            throw new Error("Registration failed");
          }

          // Tell Passport.js we're logged in
          await login(user);
          // Tell pg we're logged in
          await pgClient.query("select set_config($1, $2, true);", [
            "jwt.claims.user_id",
            user.id,
          ]);

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
      async login(
        mutation,
        args,
        context,
        resolveInfo,
        { selectGraphQLResultFromTable }
      ) {
        const { username, password } = args.input;
        const { rootPgPool, login, pgClient } = context;
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
          // Tell pg we're logged in
          await pgClient.query("select set_config($1, $2, true);", [
            "jwt.claims.user_id",
            user.id,
          ]);

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
