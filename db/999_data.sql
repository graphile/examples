select app_private.link_or_register_user(
  null,
  'github',
  '6413628',
  '{}'::json,
  '{}'::json
);

insert into app_public.user_emails(user_id, email, is_verified) values
  (1, 'user@example.com', true);

insert into app_public.forums(slug, name, description) values
  ('cat-life', 'Cat Life', 'A forum all about cats and how fluffy they are and how they completely ignore their owners unless there is food. Or yarn.'),
  ('dog-life', 'Dog Life', ''),
  ('slug-life', 'Slug Life', '');

insert into app_public.topics(forum_id, author_id, title, body) values
  (1, 1, 'cats cats cats', 'lets discuss cats because theyre totally cool'),
  (1, 1, 'snooze life', 'do you find your cat just sleeps everywhere'),
  (1, 1, 'too hot', 'its so hot my cat just flops where ever there is shade');

insert into app_public.posts(topic_id, author_id, body) values
  (1, 1, 'Dont you just love cats? Cats cats cats cats cats cats cats cats cats cats cats cats Cats cats cats cats cats cats cats cats cats cats cats cats'),
  (1, 1, 'Yeah cats are really fluffy I enjoy squising their fur they are so goregous and fluffy and squishy and fluffy and gorgeous and squishy and goregous and fluffy and squishy and fluffy and gorgeous and squishy'),
  (1, 1, 'I love it when they completely ignore you until they want something. So much better than dogs am I rite?');
