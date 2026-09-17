-- Storage: бакет для файлов документов
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

-- путь объекта: {owner_id}/{document_id}/{filename}
create policy "storage_insert_own_folder" on storage.objects
  for insert with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "storage_select_by_document_access" on storage.objects
  for select using (
    bucket_id = 'documents'
    and exists (
      select 1 from documents d
      where d.storage_path = storage.objects.name
        and (
          d.access = 'public'
          or d.owner_id = auth.uid()
          or current_user_role() = 'admin'
          or exists (
            select 1 from document_shares s
            where s.document_id = d.id and s.user_id = auth.uid()
          )
        )
    )
  );

create policy "storage_delete_owner_or_admin" on storage.objects
  for delete using (
    bucket_id = 'documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or current_user_role() = 'admin'
    )
  );
