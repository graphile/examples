PostGraphile Examples
=====================

🚨**Temporarily unmaintained**🚨 This repo is currently not maintained and is out of date - Please make sure that you update the dependancies in your copy of these examples. For an up to date example, see the [Graphile Starter](https://github.com/graphile/starter). *We rely on sponsorship from the Graphile community to continue our work in Open Source. By donating to our [GitHub Sponsors or Patreon fund](https://graphile.org/sponsor), you'll help us spend more time on Open Source, and this repo will be updated quicker. Thank you to all our sponsors 🙌*

This repository will contain examples of using PostGraphile with different servers and clients.

To get started:

```
npm install -g yarn
yarn
./setup.sh
# Now add GITHUB_KEY and GITHUB_SECRET to .env (see "Login via GitHub" below)
yarn start
```

This will run the koa2 server and react client. You can access it at http://localhost:8349/

It's recommended that you review the setup.sh script before executing it.

The first user account to log in will automatically be made an administrator.

Login via GitHub
----------------

To use social login you will need to create a GitHub application. This takes just a few seconds:

1. Visit https://github.com/settings/applications/new
2. Enter name: GraphileDemo
3. Enter homepage URL: http://localhost:8349
4. Enter authorization callback URL: http://localhost:8349/auth/github/callback
5. Press "Register Application"
6. Copy the 'Client ID' and 'Client Secret' into `GITHUB_KEY` and `GITHUB_SECRET` respectively in the `.env` file that was created by `setup.sh`

Koa2
----

Koa 2 only has "experimental" support in PostGraphile officially, but if you
face any issues please file them against PostGraphile with full reproduction
instructions - we're trying to elevate Koa to full support status.
