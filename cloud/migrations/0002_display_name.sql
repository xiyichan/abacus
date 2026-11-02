-- 用户名：只是显示名，登录仍用邮箱验证码
ALTER TABLE accounts ADD COLUMN display_name TEXT;
