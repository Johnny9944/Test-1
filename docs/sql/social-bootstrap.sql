-- wabot social-engine bootstrap  (v2, 2026-09-11)
-- 在 Supabase Dashboard → SQL Editor 里整段粘贴,点 Run 一次。
-- 做的事:建 schema social、建登录角色 social_engine(随机密码)、在 Vault 生成哈希盐、建函数 social.wa_hash()。
-- 结果:最后显示一行,含 social_db_password / wa_hash_salt / selftest_hash。整行复制给 CC-B;盐另存进密码管理器。
-- 重复 Run 是安全的:盐不会变;密码会重新生成(重新生成后要再交给 CC-B 一次)。

create extension if not exists pgcrypto with schema extensions;
create extension if not exists supabase_vault;

do $$
declare
  v_pw   text := encode(extensions.gen_random_bytes(16), 'hex');   -- 32 位,只含 0-9a-f,连接串无需转义
  v_salt text := encode(extensions.gen_random_bytes(32), 'hex');
begin
  if not exists (select 1 from pg_roles where rolname = 'social_engine') then
    execute format('create role social_engine login password %L', v_pw);
  else
    execute format('alter role social_engine with login password %L', v_pw);
  end if;

  -- postgres 要能 SET ROLE 到 social_engine 才能把 schema 的 owner 交给它
  execute 'grant social_engine to postgres';

  create schema if not exists social;
  execute 'alter schema social owner to social_engine';
  execute 'grant usage on schema extensions to social_engine';

  if not exists (select 1 from vault.secrets where name = 'wa_hash_salt') then
    perform vault.create_secret(v_salt, 'wa_hash_salt', 'wabot social-engine phone hash salt');
  end if;

  create temp table if not exists _bootstrap_out (k text, v text);
  delete from _bootstrap_out;
  insert into _bootstrap_out values ('SOCIAL_DB_PASSWORD', v_pw);
end $$;

-- 客户电话哈希(去重用)。SECURITY DEFINER:调用者拿不到盐。
create or replace function social.wa_hash(p_phone text)
returns text
language sql
security definer
set search_path = ''
as $$
  select encode(
    extensions.hmac(
      regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'),
      (select s.decrypted_secret from vault.decrypted_secrets s where s.name = 'wa_hash_salt' limit 1),
      'sha256'),
    'hex');
$$;
revoke all on function social.wa_hash(text) from public;
grant execute on function social.wa_hash(text) to social_engine;

-- 结果行:整行复制给 CC-B;wa_hash_salt 另存进密码管理器。
select
  (select v from _bootstrap_out where k = 'SOCIAL_DB_PASSWORD')                        as social_db_password,
  (select s.decrypted_secret from vault.decrypted_secrets s where s.name = 'wa_hash_salt') as wa_hash_salt,
  social.wa_hash('+60 12-345 6789')                                                    as selftest_hash;
