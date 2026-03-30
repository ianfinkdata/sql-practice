import pandas as pd
import random
from faker import Faker
import json
from datetime import datetime, timedelta

# 1. Initialize Faker (This is our synthetic data engine)
fake = Faker()

# 2. Load our existing Bronze tables into Pandas DataFrames
df_customers = pd.read_csv(r"C:\Users\ianfi\OneDrive\Documents\GitHub\sql-practice\python\sp_customers.csv")
df_sales = pd.read_csv(r"C:\Users\ianfi\OneDrive\Documents\GitHub\sql-practice\python\sp_sales.csv")
df_reps = pd.read_csv(r"C:\Users\ianfi\OneDrive\Documents\GitHub\sql-practice\python\sp_sales_rep.csv")

# --- ADD THESE TWO LINES TO FIX THE ERROR ---
# Force the ID columns to be numeric so we can do math on them
df_customers['customer_id'] = pd.to_numeric(df_customers['customer_id'])
df_sales['sale_id'] = pd.to_numeric(df_sales['sale_id'])
# ------------------------------------------

print("Existing data loaded successfully!")

# ==========================================
# PART A: GENERATE NEW CUSTOMERS
# ==========================================
new_customers = []
# Find the highest existing customer_id so we can continue counting from there
start_cust_id = df_customers['customer_id'].max() + 1 
regions = ['Midwest', 'Northeast', 'West', 'South']

for i in range(50): # Generate 50 new customers
    new_id = start_cust_id + i
    name = fake.company()
    
    # Create the JSON array exactly how your SQL expects it
    contact_json = [
        {"type": "email", "value": fake.company_email()},
        {"type": "phone", "value": fake.phone_number()}
    ]
    
    new_customers.append({
        'customer_id': new_id,
        'contact_details': json.dumps(contact_json), # Converts Python list to JSON string
        'customer_name': name,
        'region': random.choice(regions)
    })

# Convert the list of new customers to a DataFrame and combine it with the old ones
df_new_customers = pd.DataFrame(new_customers)
df_customers = pd.concat([df_customers, df_new_customers], ignore_index=True)


# ==========================================
# PART B: GENERATE NEW SALES
# ==========================================
new_sales = []
start_sale_id = df_sales['sale_id'].max() + 1

# Get a list of all valid customer IDs and rep IDs to randomly pick from
all_customer_ids = df_customers['customer_id'].tolist()
all_rep_ids = df_reps['rep_id'].tolist()

# Define a start and end date for our synthetic sales
start_date = datetime(2025, 1, 1)
end_date = datetime(2026, 3, 31)
days_between = (end_date - start_date).days

for i in range(500): # Generate 500 new sales
    new_id = start_sale_id + i
    
    # Generate a random date between start_date and end_date
    random_days = random.randrange(days_between)
    sale_date = start_date + timedelta(days=random_days)
    
    new_sales.append({
        'sale_id': new_id,
        'sale_date': sale_date.strftime('%Y-%m-%d'), # Format as YYYY-MM-DD
        'customer_id': random.choice(all_customer_ids),
        'rep_id': random.choice(all_rep_ids),
        'sale_amount': round(random.uniform(500.00, 15000.00), 2) # Random dollar amount
    })

# Convert new sales to DataFrame and combine
df_new_sales = pd.DataFrame(new_sales)
df_sales = pd.concat([df_sales, df_new_sales], ignore_index=True)


# ==========================================
# PART C: EXPORT ENRICHED DATA
# ==========================================
# Save the new, massive tables over the old CSV files (or save as new files)
df_customers.to_csv('sp_customers_enriched.csv', index=False)
df_sales.to_csv('sp_sales_enriched.csv', index=False)

print(f"Success! Added 50 new customers and 500 new sales.")
print("Saved as 'sp_customers_enriched.csv' and 'sp_sales_enriched.csv'")