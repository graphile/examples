# Database

Since this is a realistic example, it has realistic concerns in it, such as
mitigating brute force login attacks. This means that the example might be a
lot bigger than you'd first expect; but it's designed to be a solid start you
can use in your own applications (after a find and replace for 'graphiledemo'!)
so when you start, jump straight to the files >= 500 as they contain the forum
application logic.

Note also that this application works with both social (OAuth) login (when used
with a server that supports this), and with traditional username/password
login, and the social login stores your access tokens so that the server-side
may use them (e.g. to look up issues in GitHub when they're mentioned in one of
your posts). This means the user tables might be significantly more complex
than your application requires; feel free to simplify them when you build your
own schema.

### Conventions

With the exception of `100_jobs.sql` which was imported from a previous project
and requires bringing in line, the SQL files in this repository try to adhere
to the conventions defined in [CONVENTIONS.md](./CONVENTIONS.md). PRs to fix
our adherence to these conventions would be welcome. Someone writing an SQL
equivalent of ESLint and/or prettier would be even more welcome!

### Common logic

Definitions < 500 are common to all sorts of applications, they solve common
concerns such as storing user data, logging people in, triggering password
reset emails, avoiding brute force attacks and more.

`100_jobs.sql`: handles the job queue (tasks to run in the background, such
as sending emails, polling APIs, etc).

`200_schemas.sql`: defines our common schemas `app_public`, and `app_private`
and adds base permissions to them.

`300_utils.sql`: Useful utility functions.

`400_users.sql`: Users, authentication, emails, brute force mitigation, etc.


### Application specific logic

Definitions >= 500 are application specific, defining the tables in your
application, and dealing with concerns such as a welcome email or customising
the user tables to your whim. We use them here to add our forum-specific logic.

`700_forum.sql`

### Migrations

This project doesn't currently deal with migrations. Every time you pull down a
new version you should reset your database; we do not (currently) care about
supporting legacy versions of this example repo. There are many projects that
help you deal with migrations, two of note are [sqitch](https://sqitch.org/)
and
[db-migrate](https://db-migrate.readthedocs.io/en/latest/Getting%20Started/usage/).
