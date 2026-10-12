"""
Generates a synthetic pharma sales dataset.

Outputs (in ./raw):
  dim_region.csv, dim_drug.csv, dim_rep.csv  -> clean dimension tables
  sales_raw.csv                              -> deliberately DIRTY transactions
                                                (duplicates, casing/whitespace,
                                                mixed date formats, nulls,
                                                negative units) so the SQL
                                                cleaning step has real work to do.
Run:  python generate_data.py
"""
import csv
import os
import random
from datetime import date, timedelta

random.seed(42)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")
os.makedirs(OUT, exist_ok=True)

REGIONS = [
    (1, "North"), (2, "South"), (3, "East"), (4, "West"), (5, "Central"),
]

# drug_id, name, category, unit_price (INR)
DRUGS = [
    (1, "Paracetamol 500", "Analgesic", 12.0),
    (2, "Ibuprofen 400", "Analgesic", 18.0),
    (3, "Diclofenac 50", "Analgesic", 22.0),
    (4, "Amoxicillin 500", "Antibiotic", 65.0),
    (5, "Azithromycin 250", "Antibiotic", 95.0),
    (6, "Ciprofloxacin 500", "Antibiotic", 80.0),
    (7, "Metformin 500", "Antidiabetic", 28.0),
    (8, "Glimepiride 2", "Antidiabetic", 45.0),
    (9, "Insulin Glargine", "Antidiabetic", 780.0),
    (10, "Amlodipine 5", "Cardiovascular", 30.0),
    (11, "Atorvastatin 10", "Cardiovascular", 55.0),
    (12, "Telmisartan 40", "Cardiovascular", 70.0),
    (13, "Omeprazole 20", "Gastrointestinal", 35.0),
    (14, "Pantoprazole 40", "Gastrointestinal", 48.0),
    (15, "Cetirizine 10", "Antihistamine", 15.0),
    (16, "Montelukast 10", "Respiratory", 85.0),
    (17, "Salbutamol Inhaler", "Respiratory", 140.0),
    (18, "Vitamin D3 60K", "Supplement", 40.0),
]

REP_NAMES = [
    "Aarav Sharma", "Vivaan Gupta", "Aditya Verma", "Ananya Singh", "Diya Patel",
    "Rohan Mehta", "Ishita Nair", "Kabir Reddy", "Meera Iyer", "Arjun Das",
    "Sneha Kulkarni", "Rahul Joshi", "Pooja Bansal", "Karan Malhotra", "Neha Chopra",
    "Siddharth Rao", "Tanvi Desai", "Manish Yadav", "Kavya Menon", "Varun Saxena",
]
REPS = [(i + 1, n, (i % len(REGIONS)) + 1) for i, n in enumerate(REP_NAMES)]

# Regional multiplier + yearly growth to make YoY interesting
REGION_W = {1: 1.15, 2: 1.0, 3: 0.85, 4: 1.2, 5: 0.7}
YEAR_G = {2023: 1.00, 2024: 1.12, 2025: 1.25}
CAT_SEASON = {  # month -> multiplier for specific categories
    "Antibiotic": {6: 1.3, 7: 1.4, 8: 1.3, 12: 1.2},
    "Respiratory": {11: 1.3, 12: 1.4, 1: 1.4, 2: 1.2},
    "Antihistamine": {3: 1.3, 4: 1.3, 10: 1.2},
}


def write(name, header, rows):
    with open(os.path.join(OUT, name), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


write("dim_region.csv", ["region_id", "region_name"], REGIONS)
write("dim_drug.csv", ["drug_id", "drug_name", "category", "unit_price"], DRUGS)
write("dim_rep.csv", ["rep_id", "rep_name", "region_id"], REPS)

reg_name = dict(REGIONS)
rows = []
txn = 100000
d = date(2023, 1, 1)
end = date(2025, 12, 31)
while d <= end:
    n_today = random.randint(8, 16)
    for _ in range(n_today):
        rep_id, rep_name, region_id = random.choice(REPS)
        drug_id, drug_name, cat, price = random.choice(DRUGS)
        base = random.randint(20, 220)
        mult = (REGION_W[region_id] * YEAR_G[d.year]
                * CAT_SEASON.get(cat, {}).get(d.month, 1.0))
        units = max(1, int(base * mult))
        if price > 500:
            units = max(1, units // 8)
        disc = random.choice([0, 0, 2.5, 5, 7.5, 10])
        txn += 1
        rows.append({
            "txn_id": f"T{txn}", "date": d, "region": reg_name[region_id],
            "drug": drug_name, "rep": rep_name, "units": units,
            "price": price, "disc": disc,
        })
    d += timedelta(days=1)

# ---- Make it dirty ----------------------------------------------------
out = []
for r in rows:
    date_str = (r["date"].strftime("%Y-%m-%d") if random.random() < 0.85
                else r["date"].strftime("%d/%m/%Y"))
    region = r["region"]
    x = random.random()
    if x < 0.04:
        region = region.upper()
    elif x < 0.08:
        region = f"  {region.lower()} "
    drug = r["drug"] if random.random() > 0.03 else f" {r['drug'].upper()}"
    units = r["units"]
    y = random.random()
    if y < 0.01:
        units = ""            # missing
    elif y < 0.02:
        units = -units        # invalid (return / data entry error)
    price = r["price"] if random.random() > 0.03 else ""  # missing price
    disc = r["disc"] if random.random() > 0.02 else ""    # missing discount
    out.append([r["txn_id"], date_str, region, drug, r["rep"], units, price, disc])

# duplicate ~2% of rows
out += random.sample(out, int(len(out) * 0.02))
random.shuffle(out)

write("sales_raw.csv",
      ["txn_id", "sale_date", "region", "drug_name", "rep_name",
       "units_sold", "unit_price", "discount_pct"], out)

print(f"Wrote {len(out)} raw sales rows to {OUT}")
