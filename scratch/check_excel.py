import pandas as pd
import os

folder = r'c:\Users\ahors\Documents\timetable\exmapleData'
files = ['Book1.xlsx', 'Book3.xlsx', 'Book4.xlsx', 'Copy of Book2(1).xlsx']

for file in files:
    path = os.path.join(folder, file)
    print(f"\n--- {file} ---")
    try:
        df = pd.read_excel(path)
        print("Columns:", df.columns.tolist())
        print("First 2 rows:")
        print(df.head(2).to_string())
    except Exception as e:
        print(f"Error reading {file}: {e}")
