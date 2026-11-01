/// SQLite schema for the phone-only database. Ported from
/// `supabase/migrations/0001`–`0022`; see [AppDatabase] for the integer
/// conventions (`_cents`, `_milli`, microsecond `_at`).
///
/// The Postgres checks that guarded money are kept as SQLite CHECKs, so a bug
/// in a Dart writer fails loudly instead of storing a wrong row.
library;

/// Bump when [migrations] gains an entry.
const schemaVersion = 2;

/// Statements run on top of [schemaStatements] when upgrading TO a version.
const migrations = <int, List<String>>{
  2: [_productBarcodes, _productBarcodesIndex],
};

// Barcodes printed on packs, learned from confirmed scans. One product per
// code; a product can have several (pack sizes, reprints).
const _productBarcodes = '''
  CREATE TABLE product_barcodes (
    barcode     TEXT PRIMARY KEY,
    product_id  TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    created_at  INTEGER NOT NULL
  )''';
const _productBarcodesIndex =
    'CREATE INDEX idx_product_barcodes_product ON product_barcodes (product_id)';

const schemaStatements = <String>[
  '''
  CREATE TABLE shops (
    id          TEXT PRIMARY KEY,
    owner_id    TEXT NOT NULL DEFAULT 'local',
    name        TEXT NOT NULL,
    address     TEXT,
    phone       TEXT,
    currency    TEXT NOT NULL DEFAULT 'BDT',
    created_at  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL
  )''',
  '''
  CREATE TABLE categories (
    id              TEXT PRIMARY KEY,
    shop_id         TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    name_normalized TEXT NOT NULL,
    created_at      INTEGER NOT NULL,
    UNIQUE (shop_id, name_normalized)
  )''',
  '''
  CREATE TABLE products (
    id                      TEXT PRIMARY KEY,
    shop_id                 TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    name                    TEXT NOT NULL,
    brand                   TEXT,
    variant                 TEXT,
    category                TEXT,
    category_id             TEXT REFERENCES categories(id) ON DELETE SET NULL,
    unit_type               TEXT NOT NULL DEFAULT 'piece'
                              CHECK (unit_type IN ('piece', 'weight', 'volume')),
    unit                    TEXT NOT NULL DEFAULT 'pcs'
                              CHECK (unit IN ('pcs', 'kg', 'g', 'litre', 'ml')),
    quantity_milli          INTEGER NOT NULL DEFAULT 0 CHECK (quantity_milli >= 0),
    buying_price_cents      INTEGER NOT NULL DEFAULT 0,
    selling_price_cents     INTEGER NOT NULL DEFAULT 0,
    reorder_threshold_milli INTEGER NOT NULL DEFAULT 0,
    expiry_warn_days        INTEGER CHECK (expiry_warn_days >= 0),
    image_urls              TEXT NOT NULL DEFAULT '',
    is_archived             INTEGER NOT NULL DEFAULT 0,
    created_at              INTEGER NOT NULL,
    updated_at              INTEGER NOT NULL
  )''',
  'CREATE INDEX idx_products_shop ON products (shop_id, is_archived)',
  'CREATE INDEX idx_products_category ON products (category_id)',
  '''
  CREATE TABLE product_batches (
    id                 TEXT PRIMARY KEY,
    shop_id            TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    product_id         TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity_milli     INTEGER NOT NULL CHECK (quantity_milli > 0),
    buying_price_cents INTEGER NOT NULL DEFAULT 0,
    received_on        TEXT NOT NULL,
    expiry_date        TEXT NOT NULL,
    expired_qty_milli  INTEGER CHECK (expired_qty_milli >= 0),
    picked_qty_milli   INTEGER NOT NULL DEFAULT 0 CHECK (picked_qty_milli >= 0),
    closed_at          INTEGER,
    closed_reason      TEXT CHECK (closed_reason IN
                         ('removed', 'none_left', 'not_expired', 'sold_out')),
    created_at         INTEGER NOT NULL
  )''',
  '''
  CREATE INDEX idx_product_batches_open
    ON product_batches (shop_id, product_id) WHERE closed_at IS NULL''',
  '''
  CREATE TABLE transactions (
    id                    TEXT PRIMARY KEY,
    shop_id               TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    product_id            TEXT NOT NULL REFERENCES products(id),
    type                  TEXT NOT NULL CHECK (type IN ('sale', 'restock', 'adjustment')),
    quantity_milli        INTEGER NOT NULL,
    buying_price_cents    INTEGER NOT NULL,
    selling_price_cents   INTEGER NOT NULL,
    discount_amount_cents INTEGER NOT NULL DEFAULT 0
                            CHECK (discount_amount_cents >= 0),
    source                TEXT CHECK (source IN ('voice', 'image', 'manual')),
    sale_group_id         TEXT,
    batch_id              TEXT REFERENCES product_batches(id) ON DELETE SET NULL,
    payment_method        TEXT CHECK (payment_method IN ('cash', 'digital', 'credit')),
    created_at            INTEGER NOT NULL,
    -- transactions_discount_within_line (0009), in integer units:
    -- cents * 1000 vs cents * milli.
    CHECK (discount_amount_cents * 1000 <= selling_price_cents * quantity_milli)
  )''',
  'CREATE INDEX idx_transactions_shop_created ON transactions (shop_id, type, created_at)',
  'CREATE INDEX idx_transactions_product ON transactions (product_id, type, created_at)',
  'CREATE INDEX idx_transactions_sale_group ON transactions (sale_group_id)',
  '''
  CREATE TABLE customers (
    id          TEXT PRIMARY KEY,
    shop_id     TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    phone       TEXT NOT NULL,
    note        TEXT,
    created_at  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL
  )''',
  'CREATE INDEX idx_customers_shop ON customers (shop_id)',
  '''
  CREATE TABLE customer_ledger (
    id            TEXT PRIMARY KEY,
    shop_id       TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    customer_id   TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    entry_type    TEXT NOT NULL CHECK (entry_type IN ('credit_sale', 'payment')),
    amount_cents  INTEGER NOT NULL CHECK (amount_cents > 0),
    sale_group_id TEXT,
    note          TEXT,
    created_at    INTEGER NOT NULL
  )''',
  '''
  CREATE INDEX idx_customer_ledger_customer
    ON customer_ledger (customer_id, created_at)''',
  'CREATE INDEX idx_customer_ledger_shop ON customer_ledger (shop_id, entry_type)',

  // ---------------------------------------------------------------------------
  // On-device AI (design §5a). Nothing here leaves the phone.
  // ---------------------------------------------------------------------------
  // One "fingerprint" per photo of a product: the EasySell Vision embedding
  // (float32 little-endian, L2-normalised). `model` names the model version
  // that made it, so a model update can re-embed instead of mixing spaces.
  '''
  CREATE TABLE product_embeddings (
    id          TEXT PRIMARY KEY,
    product_id  TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    model       TEXT NOT NULL,
    vector      BLOB NOT NULL,
    source      TEXT NOT NULL CHECK (source IN ('enroll', 'scan')),
    thumb_path  TEXT,
    created_at  INTEGER NOT NULL
  )''',
  'CREATE INDEX idx_product_embeddings_product ON product_embeddings (product_id, created_at)',
  // Words the shopkeeper used for a product, learned from voice corrections.
  '''
  CREATE TABLE product_aliases (
    id                TEXT PRIMARY KEY,
    product_id        TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    phrase            TEXT NOT NULL,
    phrase_normalized TEXT NOT NULL,
    hits              INTEGER NOT NULL DEFAULT 1,
    created_at        INTEGER NOT NULL,
    updated_at        INTEGER NOT NULL,
    UNIQUE (product_id, phrase_normalized)
  )''',
  'CREATE INDEX idx_product_aliases_phrase ON product_aliases (phrase_normalized)',
  _productBarcodes,
  _productBarcodesIndex,
];

/// Starter categories for a new shop (0003 `seed_default_categories`).
const defaultCategoryNames = <String>[
  'Rice & grains',
  'Cooking oil',
  'Pulses/lentils',
  'Vegetables',
  'Spices',
  'Cleaning & detergent',
  'Personal care',
  'Beverages',
  'Snacks',
  'Dairy',
];
