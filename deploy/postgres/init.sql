-- Chạy một lần khi volume PostgreSQL còn trống.
-- Image đã tạo role "animal" (POSTGRES_USER) và database billing_db (POSTGRES_DB); ở đây thêm database riêng cho Keycloak.
-- Dev dùng chung một server với hai database (đúng kế hoạch kiến trúc, mục 10).
SELECT 'CREATE DATABASE keycloak_db OWNER animal ENCODING ''UTF8'''
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak_db')\gexec

-- Hai database không được kết nối chéo từ role khác.
REVOKE ALL ON DATABASE keycloak_db FROM PUBLIC;
REVOKE ALL ON DATABASE billing_db FROM PUBLIC;
-- Production: tách Keycloak sang instance riêng, dùng role riêng cho billing và cho keycloak.
