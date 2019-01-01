select app_private.link_or_register_user(
  null,
  'github',
  '6413628',
  '{}'::json,
  '{}'::json
);
select app_private.link_or_register_user(
  null,
  'github',
  '222222',
  '{"name":"Chad F"}'::json,
  '{}'::json
);
select app_private.link_or_register_user(
  null,
  'github',
  '333333',
  '{"name":"Bradley A"}'::json,
  '{}'::json
);
select app_private.link_or_register_user(
  null,
  'github',
  '444444',
  '{"name":"Sam L"}'::json,
  '{}'::json
);
select app_private.link_or_register_user(
  null,
  'github',
  '555555',
  '{"name":"Max D"}'::json,
  '{}'::json
);

insert into app_public.user_emails(user_id, email, is_verified) values
  (1, 'benjie@example.com', true);

insert into app_public.forums(slug, name, description) values
  ('testimonials', 'Testimonials', 'How do you rate PostGraphile?'),
  ('feedback', 'Feedback', 'How are you finding PostGraphile?');

insert into app_public.topics(forum_id, author_id, title, body) values
  (1, 2, 'Thank you!', '500-1500 requests per second on a single server is pretty awesome.'),
  (1, 4, 'PostGraphile is powerful', 'PostGraphile is a powerful, idomatic, and elegant tool.'),
  (1, 5, 'Recently launched', 'At this point, it’s quite hard for me to come back and enjoy working with REST.');

insert into app_public.posts(topic_id, author_id, body) values
  (1, 1, 'Dont you just love cats? Cats cats cats cats cats cats cats cats cats cats cats cats Cats cats cats cats cats cats cats cats cats cats cats cats'),
  (1, 1, 'Yeah cats are really fluffy I enjoy squising their fur they are so goregous and fluffy and squishy and fluffy and gorgeous and squishy and goregous and fluffy and squishy and fluffy and gorgeous and squishy'),
  (1, 1, 'I love it when they completely ignore you until they want something. So much better than dogs am I rite?');
