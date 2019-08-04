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
      user: User! @pgField
    }

    input LoginInput {
      username: String!
      password: String!
    }

    type LoginPayload {
      user: User! @pgField
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
        const {
          username,
          password,
          email,
          name = null,
          avatarUrl = null,
        } = args.input;
        const { rootPgPool, login, pgClient } = context;
        try {
          // Call our register function from the database
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
            ) users where not (users is null)`,
            [username, email, name, avatarUrl, password]
          );

          if (!user) {
            throw new Error("Registration failed");
          }

          const sql = build.pgSql;

          const results = await Promise.all([
            // Fetch the data that was requested from GraphQL, and return it
            selectGraphQLResultFromTable(
              sql.fragment`app_public.users`,
              (tableAlias, sqlBuilder) => {
                sqlBuilder.where(
                  sql.fragment`${tableAlias}.id = ${sql.value(user.id)}`
                );
              }
            ),

            // Tell Passport.js we're logged in
            login(user),

            // Tell pg we're logged in
            pgClient.query("select set_config($1, $2, true);", [
              "jwt.claims.user_id",
              user.id,
            ]),
          ]);

          const [row] = results[0];
          return {
            data: row,
          };
        } catch (e) {
          console.error(e);
          throw e;
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
            `select users.* from app_private.login($1, $2) users where not (users is null)`,
            [username, password]
          );

          if (!user) {
            throw new Error("Login failed");
          }

          const sql = build.pgSql;

          const results = await Promise.all([
            // Fetch the data that was requested from GraphQL, and return it
            selectGraphQLResultFromTable(
              sql.fragment`app_public.users`,
              (tableAlias, sqlBuilder) => {
                sqlBuilder.where(
                  sql.fragment`${tableAlias}.id = ${sql.value(user.id)}`
                );
              }
            ),

            // Tell Passport.js we're logged in
            login(user),

            // Tell pg we're logged in
            pgClient.query("select set_config($1, $2, true);", [
              "jwt.claims.user_id",
              user.id,
            ]),
          ]);

          const [row] = results[0];
          return {
            data: row,
          };
        } catch (e) {
          console.error(e);
          throw e;
        }
      },
    },
  },
}));
module.exports = PassportLoginPlugin;
