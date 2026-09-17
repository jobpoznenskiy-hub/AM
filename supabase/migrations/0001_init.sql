-- АМБКД: базовая схема (демо/внутренний прототип)
-- Роли: admin (Адміністратор), editor (Редактор), reader (Читач)

create type user_role as enum ('admin', 'editor', 'reader');
create type user_status as enum ('active', 'pending');
create type doc_access as enum ('public', 'private');
create type share_permission as enum ('reader', 'editor', 'admin');

create table institutions (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null,
  phone text,
  birth_date date,
  position text,
  department text,
  institution_id uuid references institutions(id),
  role user_role not null default 'reader',
  status user_status not null default 'active',
  avatar_url text,
  created_at timestamptz not null default now()
);

create table documents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text,
  filename text not null,
  storage_path text,        -- путь в Storage, если загружен файл
  external_url text,        -- либо внешняя ссылка (Google Docs и т.п.)
  size_bytes bigint,
  category_id uuid references categories(id),
  institution_id uuid references institutions(id),
  access doc_access not null default 'private',
  owner_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table document_shares (
  document_id uuid not null references documents(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  permission share_permission not null default 'reader',
  created_at timestamptz not null default now(),
  primary key (document_id, user_id)
);

create table audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references profiles(id),
  action text not null,          -- 'upload' | 'view' | 'share' | 'delete' | 'update_profile' ...
  document_id uuid references documents(id),
  created_at timestamptz not null default now()
);

create index on documents (owner_id);
create index on documents (category_id);
create index on documents (access);
create index on document_shares (user_id);

-- seed справочников из прототипа
insert into institutions (name) values
  ('Реєстр адміністративно-територіального устрою (ЄДРАТО)'),
  ('Підключення до інженерних мереж'),
  ('Реєстр містобудівної документації (РМД)'),
  ('Адресний реєстр (ЄДРА)'),
  ('Інформаційне моделювання будівель (BIM)'),
  ('База даних енергоефективності будівель (БДЕ)'),
  ('Електронна система ціноутворення в будівництві (ЄСЦ)');

insert into categories (name) values
  ('Юридичні'), ('Фінанси'), ('Кадри'), ('Продукт'), ('Дизайн');
