const Koa = require('koa');
const { postgraphile } = require('postgraphile');

const isDev = process.env.NODE_ENV === 'development';
const app = new Koa();

app.use(async (ctx, next) => {
  if (ctx.path === '/') {
    ctx.redirect('/graphiql');
  } else {
    return next();
  }
});

app.use(postgraphile(
  process.env.AUTH_DATABASE_URL,
  'app_public',
  {
    dynamicJson: true,
    graphiql: true,
    watchPg: isDev,
    pgSettings(ctx) {
      return {
        role: 'graphiledemo_visitor',
        user_id: ctx.user && ctx.user.id,
      };
    },
  }
));

const PORT = parseInt(process.env.PORT, 10) || 3000
app.listen(PORT);
console.log(`Listening on port ${PORT}`);
