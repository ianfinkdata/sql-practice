import pandas as pd
import random
from faker import Faker
from datetime import datetime, timedelta

# 1. Initialize Faker
fake = Faker()

# 2. SIMPLE PARSER: Read the file, ignore the JSON, and set it to None
customers_path = r"C:\Users\ianfi\OneDrive\Documents\GitHub\sql-practice\python\sp_customers.csv"
parsed_data = []

with open(customers_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines[1:]: # Skip the header row
    line = line.strip()
    if not line: continue
    
    # Split the line by commas. 
    # We know ID is the very first item, Region is the very last, and Name is second-to-last.
    parts = line.split(',')
    
    parsed_data.append({
        'customer_id': int(parts[0]),
        'contact_details': None,  # Hardcoding Null here to drop the old JSON
        'customer_name': parts[-2].strip('"'), # Strip any quotes around the name
        'region': parts[-1]
    })

# Convert to a clean Pandas DataFrame
df_customers = pd.DataFrame(parsed_data)

# 3. Load the other two normally from the python folder
df_sales = pd.read_csv(r"C:\Users\ianfi\OneDrive\Documents\GitHub\sql-practice\python\sp_sales.csv")
df_reps = pd.read_csv(r"C:\Users\ianfi\OneDrive\Documents\GitHub\sql-practice\python\sp_sales_rep.csv")

# Force the sale_id to numeric just to be safe
df_sales['sale_id'] = pd.to_numeric(df_sales['sale_id'])

print("Existing data loaded successfully (JSON ignored)!")

# ==========================================
# PART A: GENERATE NEW CUSTOMERS
# ==========================================
new_customers = []
start_cust_id = df_customers['customer_id'].max() + 1 
regions = ['Midwest', 'Northeast', 'West', 'South']

for i in range(50): # Generate 50 new customers
    new_customers.append({
        'customer_id': start_cust_id + i,
        'contact_details': None, # Hardcoding Null for all new rows
        'customer_name': fake.company(),
        'region': random.choice(regions)
    })

df_new_customers = pd.DataFrame(new_customers)
df_customers = pd.concat([df_customers, df_new_customers], ignore_index=True)


# ==========================================
# PART B: GENERATE NEW SALES
# ==========================================
new_sales = []
start_sale_id = df_sales['sale_id'].max() + 1

all_customer_ids = df_customers['customer_id'].tolist()
all_rep_ids = df_reps['rep_id'].tolist()

start_date = datetime(2025, 1, 1)
end_date = datetime(2026, 3, 31)
days_between = (end_date - start_date).days

for i in range(500): # Generate 500 new sales
    random_days = random.randrange(days_between)
    sale_date = start_date + timedelta(days=random_days)
    
    new_sales.append({
        'sale_id': start_sale_id + i,
        'sale_date': sale_date.strftime('%Y-%m-%d'),
        'customer_id': random.choice(all_customer_ids),
        'rep_id': random.choice(all_rep_ids),
        'sale_amount': round(random.uniform(500.00, 15000.00), 2)
    })

df_new_sales = pd.DataFrame(new_sales)
df_sales = pd.concat([df_sales, df_new_sales], ignore_index=True)


# ==========================================
# PART C: EXPORT ENRICHED DATA
# ==========================================
# Save the files directly back into the python folder
df_customers.to_csv(r"C:\Users\ianfi\OneDrive\Documents\GitHub\sql-practice\python\sp_customers_enriched.csv", index=False)
df_sales.to_csv(r"C:\Users\ianfi\OneDrive\Documents\GitHub\sql-practice\python\sp_sales_enriched.csv", index=False)

print(f"Success! Added 50 new customers and 500 new sales.")
print("Saved as 'sp_customers_enriched.csv' and 'sp_sales_enriched.csv' in your python folder!")