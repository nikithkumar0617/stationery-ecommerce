-- ============================================================
--  STATIONERY E-COMMERCE DATABASE SCHEMA
--  Production-ready PostgreSQL design
--  Compatible with: Python Flask / SQLAlchemy
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. USERS
-- ============================================================
CREATE TABLE users (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name       VARCHAR(150)    NOT NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    phone           VARCHAR(20)     UNIQUE,
    password_hash   TEXT            NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    is_verified     BOOLEAN         NOT NULL DEFAULT FALSE,
    profile_pic_url TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 2. ADMINS
-- ============================================================
CREATE TABLE admins (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name       VARCHAR(150)    NOT NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    password_hash   TEXT            NOT NULL,
    role            VARCHAR(50)     NOT NULL DEFAULT 'staff'
                    CHECK (role IN ('superadmin', 'manager', 'staff')),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    last_login      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 3. CATEGORIES
-- ============================================================
CREATE TABLE categories (
    id              SERIAL          PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL UNIQUE,
    slug            VARCHAR(110)    NOT NULL UNIQUE,
    description     TEXT,
    parent_id       INTEGER         REFERENCES categories(id) ON DELETE SET NULL,
    image_url       TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    display_order   INTEGER         NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 4. PRODUCTS
-- ============================================================
CREATE TABLE products (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id     INTEGER         NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    name            VARCHAR(255)    NOT NULL,
    slug            VARCHAR(270)    NOT NULL UNIQUE,
    description     TEXT,
    brand           VARCHAR(100),
    sku             VARCHAR(80)     NOT NULL UNIQUE,
    price           NUMERIC(10, 2)  NOT NULL CHECK (price >= 0),
    discount_price  NUMERIC(10, 2)          CHECK (discount_price >= 0),
    stock_qty       INTEGER         NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    low_stock_alert INTEGER         NOT NULL DEFAULT 10,
    weight_grams    INTEGER,
    images          JSONB           NOT NULL DEFAULT '[]',  -- [{url, alt, is_primary}]
    attributes      JSONB           NOT NULL DEFAULT '{}',  -- {color, size, material, …}
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    is_featured     BOOLEAN         NOT NULL DEFAULT FALSE,
    average_rating  NUMERIC(3, 2)   NOT NULL DEFAULT 0.00
                    CHECK (average_rating BETWEEN 0 AND 5),
    review_count    INTEGER         NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT discount_lt_price CHECK (
        discount_price IS NULL OR discount_price < price
    )
);

-- ============================================================
-- 5. CART
-- ============================================================
CREATE TABLE cart (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    session_id      VARCHAR(128)    UNIQUE,          -- for guest carts
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT cart_owner CHECK (
        (user_id IS NOT NULL AND session_id IS NULL) OR
        (user_id IS NULL AND session_id IS NOT NULL)
    )
);

-- ============================================================
-- 6. CART_ITEMS
-- ============================================================
CREATE TABLE cart_items (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id         UUID            NOT NULL REFERENCES cart(id) ON DELETE CASCADE,
    product_id      UUID            NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity        INTEGER         NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price      NUMERIC(10, 2)  NOT NULL CHECK (unit_price >= 0), -- snapshotted at add-time
    added_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    UNIQUE (cart_id, product_id)
);

-- ============================================================
-- 7. COUPONS
-- ============================================================
CREATE TABLE coupons (
    id              SERIAL          PRIMARY KEY,
    code            VARCHAR(50)     NOT NULL UNIQUE,
    description     VARCHAR(255),
    discount_type   VARCHAR(20)     NOT NULL
                    CHECK (discount_type IN ('percentage', 'flat')),
    discount_value  NUMERIC(10, 2)  NOT NULL CHECK (discount_value > 0),
    max_discount    NUMERIC(10, 2),                  -- cap for percentage coupons
    min_order_value NUMERIC(10, 2)  NOT NULL DEFAULT 0,
    usage_limit     INTEGER,                         -- NULL = unlimited
    used_count      INTEGER         NOT NULL DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    valid_from      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    valid_until     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_date_range CHECK (
        valid_until IS NULL OR valid_until > valid_from
    )
);

-- ============================================================
-- 8. ORDERS
-- ============================================================
CREATE TABLE orders (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    coupon_id           INTEGER         REFERENCES coupons(id) ON DELETE SET NULL,
    order_number        VARCHAR(30)     NOT NULL UNIQUE,  -- e.g. ORD-20240601-0001
    status              VARCHAR(30)     NOT NULL DEFAULT 'pending'
                        CHECK (status IN (
                            'pending', 'confirmed', 'processing',
                            'shipped', 'out_for_delivery', 'delivered',
                            'cancelled', 'refunded'
                        )),
    subtotal            NUMERIC(12, 2)  NOT NULL CHECK (subtotal >= 0),
    discount_amount     NUMERIC(12, 2)  NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    shipping_charge     NUMERIC(10, 2)  NOT NULL DEFAULT 0 CHECK (shipping_charge >= 0),
    tax_amount          NUMERIC(10, 2)  NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    total_amount        NUMERIC(12, 2)  NOT NULL CHECK (total_amount >= 0),
    -- Shipping address (denormalised for historical accuracy)
    shipping_name       VARCHAR(150)    NOT NULL,
    shipping_phone      VARCHAR(20)     NOT NULL,
    shipping_address    TEXT            NOT NULL,
    shipping_city       VARCHAR(100)    NOT NULL,
    shipping_state      VARCHAR(100)    NOT NULL,
    shipping_pincode    VARCHAR(20)     NOT NULL,
    shipping_country    VARCHAR(80)     NOT NULL DEFAULT 'India',
    -- Tracking
    tracking_number     VARCHAR(100),
    shipping_carrier    VARCHAR(80),
    notes               TEXT,
    placed_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 9. ORDER_ITEMS
-- ============================================================
CREATE TABLE order_items (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID            NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id      UUID            NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    product_name    VARCHAR(255)    NOT NULL,  -- snapshot at order time
    product_sku     VARCHAR(80)     NOT NULL,
    quantity        INTEGER         NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(10, 2)  NOT NULL CHECK (unit_price >= 0),
    discount_price  NUMERIC(10, 2)           CHECK (discount_price >= 0),
    line_total      NUMERIC(12, 2)  NOT NULL CHECK (line_total >= 0)
);

-- ============================================================
-- 10. PAYMENTS
-- ============================================================
CREATE TABLE payments (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            UUID            NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    user_id             UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    amount              NUMERIC(12, 2)  NOT NULL CHECK (amount > 0),
    currency            CHAR(3)         NOT NULL DEFAULT 'INR',
    method              VARCHAR(40)     NOT NULL
                        CHECK (method IN (
                            'upi', 'credit_card', 'debit_card', 'netbanking',
                            'wallet', 'cod', 'emi'
                        )),
    status              VARCHAR(30)     NOT NULL DEFAULT 'pending'
                        CHECK (status IN (
                            'pending', 'initiated', 'success',
                            'failed', 'refunded', 'partially_refunded'
                        )),
    gateway             VARCHAR(60),                 -- razorpay, stripe, payu, …
    gateway_order_id    VARCHAR(150)    UNIQUE,
    gateway_payment_id  VARCHAR(150)    UNIQUE,
    gateway_signature   TEXT,
    failure_reason      TEXT,
    refund_amount       NUMERIC(12, 2)  CHECK (refund_amount >= 0),
    refund_id           VARCHAR(150),
    initiated_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    completed_at        TIMESTAMPTZ
);

-- ============================================================
-- INDEXES
-- ============================================================

-- Users
CREATE INDEX idx_users_email         ON users(email);
CREATE INDEX idx_users_phone         ON users(phone);
CREATE INDEX idx_users_is_active     ON users(is_active);

-- Admins
CREATE INDEX idx_admins_email        ON admins(email);
CREATE INDEX idx_admins_role         ON admins(role);

-- Categories
CREATE INDEX idx_categories_parent   ON categories(parent_id);
CREATE INDEX idx_categories_slug     ON categories(slug);

-- Products
CREATE INDEX idx_products_category   ON products(category_id);
CREATE INDEX idx_products_sku        ON products(sku);
CREATE INDEX idx_products_slug       ON products(slug);
CREATE INDEX idx_products_price      ON products(price);
CREATE INDEX idx_products_active     ON products(is_active);
CREATE INDEX idx_products_featured   ON products(is_featured);
CREATE INDEX idx_products_search     ON products USING gin(to_tsvector('english', name || ' ' || COALESCE(description, '')));

-- Cart
CREATE INDEX idx_cart_user           ON cart(user_id);
CREATE INDEX idx_cart_session        ON cart(session_id);

-- Cart items
CREATE INDEX idx_cart_items_cart     ON cart_items(cart_id);
CREATE INDEX idx_cart_items_product  ON cart_items(product_id);

-- Coupons
CREATE INDEX idx_coupons_code        ON coupons(code);
CREATE INDEX idx_coupons_active      ON coupons(is_active, valid_from, valid_until);

-- Orders
CREATE INDEX idx_orders_user         ON orders(user_id);
CREATE INDEX idx_orders_status       ON orders(status);
CREATE INDEX idx_orders_number       ON orders(order_number);
CREATE INDEX idx_orders_placed_at    ON orders(placed_at DESC);

-- Order items
CREATE INDEX idx_order_items_order   ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- Payments
CREATE INDEX idx_payments_order      ON payments(order_id);
CREATE INDEX idx_payments_user       ON payments(user_id);
CREATE INDEX idx_payments_status     ON payments(status);
CREATE INDEX idx_payments_gateway    ON payments(gateway_payment_id);

-- ============================================================
-- TRIGGERS — auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at    BEFORE UPDATE ON users    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_admins_updated_at   BEFORE UPDATE ON admins   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_cart_updated_at     BEFORE UPDATE ON cart     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_orders_updated_at   BEFORE UPDATE ON orders   FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ============================================================
-- SAMPLE DATA
-- ============================================================

-- Admins
INSERT INTO admins (full_name, email, password_hash, role) VALUES
('Rohan Mehta',  'rohan@inkcraft.in',  '$2b$12$examplehash1', 'superadmin'),
('Priya Sharma', 'priya@inkcraft.in',  '$2b$12$examplehash2', 'manager'),
('Arjun Das',    'arjun@inkcraft.in',  '$2b$12$examplehash3', 'staff');

-- Users
INSERT INTO users (full_name, email, phone, password_hash) VALUES
('Ananya Rao',      'ananya@gmail.com',  '+91-9876543210', '$2b$12$userhash1'),
('Vikram Nair',     'vikram@yahoo.com',  '+91-9123456789', '$2b$12$userhash2'),
('Sneha Kapoor',    'sneha@outlook.com', '+91-9988776655', '$2b$12$userhash3');

-- Categories (root)
INSERT INTO categories (name, slug, description, display_order) VALUES
('Writing Instruments', 'writing-instruments', 'Pens, pencils, markers and more', 1),
('Notebooks & Pads',    'notebooks-pads',       'Journals, diaries, notepads',       2),
('Art Supplies',        'art-supplies',         'Colors, brushes, canvas',            3),
('Office Essentials',   'office-essentials',    'Staplers, scissors, tapes',          4),
('Gift Sets',           'gift-sets',            'Curated stationery gift packs',      5);

-- Sub-categories
INSERT INTO categories (name, slug, description, parent_id, display_order) VALUES
('Ballpoint Pens', 'ballpoint-pens', 'Smooth writing ballpoints', 1, 1),
('Fountain Pens',  'fountain-pens',  'Premium fountain pens',     1, 2),
('Highlighters',   'highlighters',   'Multi-colour highlighters', 1, 3),
('Spiral Notebooks','spiral-notebooks','Wire-bound notebooks',    2, 1),
('Hardcover Diaries','hardcover-diaries','Premium leather diaries',2, 2);

-- Products
INSERT INTO products (category_id, name, slug, description, brand, sku, price, discount_price, stock_qty, images, attributes, is_featured) VALUES
(6,  'Reynolds Trimax Ball Pen (Pack of 5)',
     'reynolds-trimax-ball-pen-pack-5',
     'Smooth 0.7mm blue ink, ergonomic grip, long-lasting refill.',
     'Reynolds', 'SKU-001', 49.00, 39.00, 500,
     '[{"url":"https://cdn.inkcraft.in/pens/trimax.jpg","alt":"Reynolds Trimax","is_primary":true}]',
     '{"color":"Blue","tip_size":"0.7mm","ink_type":"ballpoint"}', TRUE),

(7,  'Pilot Metropolitan Fountain Pen',
     'pilot-metropolitan-fountain-pen',
     'Stainless steel nib, converter included, premium brass body.',
     'Pilot', 'SKU-002', 1299.00, 999.00, 80,
     '[{"url":"https://cdn.inkcraft.in/pens/metro.jpg","alt":"Pilot Metro","is_primary":true}]',
     '{"color":"Black","nib":"Medium","material":"Brass"}', TRUE),

(8,  'Stabilo Boss Highlighter Set of 8',
     'stabilo-boss-highlighter-set-8',
     'Chisel tip for thick/thin lines. Assorted fluorescent colours.',
     'Stabilo', 'SKU-003', 299.00, 249.00, 200,
     '[{"url":"https://cdn.inkcraft.in/high/stabilo.jpg","alt":"Stabilo Boss","is_primary":true}]',
     '{"count":"8","tip":"Chisel","colors":"Assorted"}', FALSE),

(9,  'Classmate King Spiral Notebook A4 (200 pages)',
     'classmate-king-spiral-notebook-a4-200',
     'Micro-ruled, 80 GSM paper, polypropylene cover.',
     'Classmate', 'SKU-004', 119.00, NULL, 350,
     '[{"url":"https://cdn.inkcraft.in/nb/classmate.jpg","alt":"Classmate Notebook","is_primary":true}]',
     '{"pages":200,"ruling":"Micro","gsm":80,"size":"A4"}', FALSE),

(10, 'Paperblanks Fiorito Hardcover Journal',
     'paperblanks-fiorito-hardcover-journal',
     'Italian bookbinding, acid-free 120 GSM cream paper, ribbon bookmark.',
     'Paperblanks', 'SKU-005', 1850.00, 1499.00, 45,
     '[{"url":"https://cdn.inkcraft.in/nb/paperblanks.jpg","alt":"Paperblanks Fiorito","is_primary":true}]',
     '{"pages":144,"gsm":120,"closure":"Magnetic","size":"A5"}', TRUE);

-- Coupons
INSERT INTO coupons (code, description, discount_type, discount_value, max_discount, min_order_value, usage_limit, valid_until) VALUES
('WELCOME10', '10% off for new users',            'percentage', 10,   100.00,  299.00, 1000, NOW() + INTERVAL '1 year'),
('FLAT50',    'Flat ₹50 off on orders above ₹499','flat',        50,   NULL,    499.00, 500,  NOW() + INTERVAL '3 months'),
('INKCRAFT20','20% off storewide – festive sale', 'percentage',  20,   500.00,  999.00, 200,  NOW() + INTERVAL '7 days');

-- Cart (for user Ananya)
WITH u AS (SELECT id FROM users WHERE email = 'ananya@gmail.com')
INSERT INTO cart (user_id) SELECT id FROM u;

-- Cart items
WITH c AS (SELECT id FROM cart WHERE user_id = (SELECT id FROM users WHERE email = 'ananya@gmail.com')),
     p1 AS (SELECT id, COALESCE(discount_price, price) AS ep FROM products WHERE sku = 'SKU-001'),
     p2 AS (SELECT id, COALESCE(discount_price, price) AS ep FROM products WHERE sku = 'SKU-004')
INSERT INTO cart_items (cart_id, product_id, quantity, unit_price)
SELECT c.id, p1.id, 2, p1.ep FROM c, p1
UNION ALL
SELECT c.id, p2.id, 1, p2.ep FROM c, p2;

-- Order
INSERT INTO orders (
    user_id, order_number, status,
    subtotal, discount_amount, shipping_charge, tax_amount, total_amount,
    shipping_name, shipping_phone, shipping_address, shipping_city,
    shipping_state, shipping_pincode, shipping_country
)
SELECT
    u.id,
    'ORD-20240601-0001', 'confirmed',
    1038.00, 50.00, 0.00, 0.00, 988.00,
    'Ananya Rao', '+91-9876543210',
    '42, Green Park Colony, Banjara Hills',
    'Hyderabad', 'Telangana', '500034', 'India'
FROM users u WHERE u.email = 'ananya@gmail.com';

-- Order items
INSERT INTO order_items (order_id, product_id, product_name, product_sku, quantity, unit_price, discount_price, line_total)
SELECT
    o.id,
    p.id,
    p.name,
    p.sku,
    2,
    p.price,
    p.discount_price,
    2 * COALESCE(p.discount_price, p.price)
FROM orders o, products p
WHERE o.order_number = 'ORD-20240601-0001' AND p.sku = 'SKU-001'
UNION ALL
SELECT
    o.id,
    p.id,
    p.name,
    p.sku,
    1,
    p.price,
    p.discount_price,
    1 * COALESCE(p.discount_price, p.price)
FROM orders o, products p
WHERE o.order_number = 'ORD-20240601-0001' AND p.sku = 'SKU-004';

-- Payment
INSERT INTO payments (order_id, user_id, amount, method, status, gateway, gateway_order_id, gateway_payment_id)
SELECT
    o.id,
    o.user_id,
    988.00,
    'upi',
    'success',
    'razorpay',
    'order_RZP123456',
    'pay_RZP789012'
FROM orders o WHERE o.order_number = 'ORD-20240601-0001';