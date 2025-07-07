-- Enable RLS on reviews table
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Create policies for reviews table
CREATE POLICY "Users can view all reviews"
ON reviews FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Users can insert their own reviews"
ON reviews FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid() AND
  rating >= 1 AND
  rating <= 5 AND
  EXISTS (
    SELECT 1 FROM order_items
    JOIN orders ON order_items.order_id = orders.id
    WHERE order_items.product_id = reviews.product_id
    AND orders.customer_id = auth.uid()
  )
);

CREATE POLICY "Users can update their own reviews"
ON reviews FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (
  user_id = auth.uid() AND
  rating >= 1 AND
  rating <= 5
);

CREATE POLICY "Users can delete their own reviews"
ON reviews FOR DELETE
TO authenticated
USING (user_id = auth.uid()); 