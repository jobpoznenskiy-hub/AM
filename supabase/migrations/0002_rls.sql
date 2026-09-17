-- Row Level Security

alter table profiles enable row level security;
alter table institutions enable row level security;
alter table categories enable row level security;
alter table documents enable row level security;
alter table document_shares enable row level security;
alter table audit_log enable row level security;

-- helper: текущая роль пользователя
create or replace function current_user_role()
returns user_role
language sql stable security definer
as $$
  select role from profiles where id = auth.uid();
$$;

-- profiles: все авторизованные видят всех (нужен справочник людей для шаринга),
-- каждый редактирует только себя, admin редактирует любого
create policy "profiles_select_authenticated" on profiles
  for select using (auth.role() = 'authenticated');

create policy "profiles_insert_self" on profiles
  for insert with check (auth.uid() = id);

create policy "profiles_update_self_or_admin" on profiles
  for update using (auth.uid() = id or current_user_role() = 'admin');

-- справочники: читать может любой авторизованный
create policy "institutions_select" on institutions
  for select using (auth.role() = 'authenticated');

create policy "categories_select" on categories
  for select using (auth.role() = 'authenticated');

-- documents: видно если публичный, свой, расшарен явно, или ты admin
create policy "documents_select" on documents
  for select using (
    access = 'public'
    or owner_id = auth.uid()
    or current_user_role() = 'admin'
    or exists (
      select 1 from document_shares s
      where s.document_id = documents.id and s.user_id = auth.uid()
    )
  );

create policy "documents_insert_own" on documents
  for insert with check (owner_id = auth.uid());

create policy "documents_update_owner_or_admin" on documents
  for update using (owner_id = auth.uid() or current_user_role() = 'admin');

create policy "documents_delete_owner_or_admin" on documents
  for delete using (owner_id = auth.uid() or current_user_role() = 'admin');

-- document_shares: управляет владелец документа или admin; сам приглашённый видит свою запись
create policy "shares_select" on document_shares
  for select using (
    user_id = auth.uid()
    or current_user_role() = 'admin'
    or exists (select 1 from documents d where d.id = document_id and d.owner_id = auth.uid())
  );

create policy "shares_insert" on document_shares
  for insert with check (
    current_user_role() = 'admin'
    or exists (select 1 from documents d where d.id = document_id and d.owner_id = auth.uid())
  );

create policy "shares_delete" on document_shares
  for delete using (
    current_user_role() = 'admin'
    or exists (select 1 from documents d where d.id = document_id and d.owner_id = auth.uid())
  );

-- audit_log: писать может любой авторизованный (за себя), читать — только admin
create policy "audit_insert_self" on audit_log
  for insert with check (actor_id = auth.uid());

create policy "audit_select_admin" on audit_log
  for select using (current_user_role() = 'admin');

-- при регистрации пользователя в auth.users — автоматически создаём профиль
create or replace function handle_new_user()
returns trigger
language plpgsql security definer
as $$
begin
  insert into public.profiles (id, full_name, email, role, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    new.email,
    'reader',
    'active'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
