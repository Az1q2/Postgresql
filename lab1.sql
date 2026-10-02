-- 1. Пользователи
CREATE TABLE users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE CHECK (email LIKE '%_@_%'),
    phone TEXT UNIQUE,
    role TEXT NOT NULL DEFAULT 'buyer' CHECK (role IN ('buyer', 'seller', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);