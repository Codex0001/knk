-- Enable UUID Extension for Unique IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- USERS TABLE (Customers, Merchants & Admins)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  role TEXT CHECK (role IN ('customer', 'merchant', 'admin')) DEFAULT 'customer',
  profile_picture TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- MERCHANTS TABLE (Store Owners)
CREATE TABLE merchants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
  business_name TEXT NOT NULL UNIQUE,
  business_email TEXT NOT NULL UNIQUE,
  phone TEXT,
  logo TEXT,
  status TEXT CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW()
);

-- CATEGORIES TABLE (Product Categories)
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE
);

-- PRODUCTS TABLE (Product Listings)
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  category_id UUID REFERENCES categories(id),
  stock_quantity INTEGER NOT NULL DEFAULT 0,
  images TEXT[], -- Array of image URLs
  created_at TIMESTAMP DEFAULT NOW()
);

-- INVENTORY TABLE (Stock Management)
CREATE TABLE inventory (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  stock_change INTEGER NOT NULL,
  reason TEXT CHECK (reason IN ('sale', 'restock', 'return')) DEFAULT 'sale',
  created_at TIMESTAMP DEFAULT NOW()
);

-- ORDERS TABLE (Customer Orders)
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  total_price DECIMAL(10,2) NOT NULL,
  status TEXT CHECK (status IN ('pending', 'shipped', 'delivered', 'cancelled')) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW()
);

-- ORDER_ITEMS TABLE (Items in an Order)
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL,
  price DECIMAL(10,2) NOT NULL
);

-- PAYMENTS TABLE (Transaction Records)
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  payment_method TEXT CHECK (payment_method IN ('stripe', 'mpesa')),
  status TEXT CHECK (status IN ('pending', 'completed', 'failed')) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW()
);

-- COUPONS TABLE (Discount Codes)
CREATE TABLE coupons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  discount_percentage DECIMAL(5,2) CHECK (discount_percentage BETWEEN 0 AND 100),
  expires_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- REVIEWS TABLE (Customer Ratings & Reviews)
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  review_text TEXT,
  images TEXT[], -- Optional images
  created_at TIMESTAMP DEFAULT NOW()
);

-- WISHLIST TABLE (User Favorite Products)
CREATE TABLE wishlist (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- NOTIFICATIONS TABLE (Push & Email Alerts)
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  type TEXT CHECK (type IN ('order', 'promo', 'general')),
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ADDRESSES TABLE (Shipping & Billing Info)
CREATE TABLE addresses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  street_address TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  postal_code TEXT NOT NULL,
  country TEXT NOT NULL,
  phone TEXT NOT NULL,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- INDEXES FOR FASTER QUERIES
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_merchants_email ON merchants(business_email);
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_payments_order ON payments(order_id);

-- DEFAULT ADMIN USER (FOR TESTING)
INSERT INTO users (first_name, last_name, email, password, role) 
VALUES ('Admin', 'User', 'admin@knitkits.com', 'hashed_password', 'admin');



-- Enable Row-Level Security (RLS) on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;

-- Users can only view & update their own profile
CREATE POLICY "Users can update their own profile"
ON users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Merchants can only view and manage their own store
CREATE POLICY "Merchants can view their store"
ON merchants FOR SELECT
USING (auth.uid() = owner_id);

CREATE POLICY "Merchants can update their store"
ON merchants FOR UPDATE
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Merchants can delete their store"
ON merchants FOR DELETE
USING (auth.uid() = owner_id);

-- Customers can only view their own orders
CREATE POLICY "Customers can view their orders"
ON orders FOR SELECT
USING (auth.uid() = user_id);

-- Customers can only see their own wishlist
CREATE POLICY "Customers can manage their wishlist"
ON wishlist FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Customers can add to wishlist"
ON wishlist FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Customers can remove from wishlist"
ON wishlist FOR DELETE
USING (auth.uid() = user_id);

-- Customers can manage their addresses
CREATE POLICY "Customers can manage their addresses"
ON addresses FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Customers can add an address"
ON addresses FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Customers can update their address"
ON addresses FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Customers can delete their address"
ON addresses FOR DELETE
USING (auth.uid() = user_id);
