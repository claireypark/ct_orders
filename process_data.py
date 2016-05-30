
# coding: utf-8

# Get raw data from database

import pandas as pd

# Get data from database
import sqlalchemy as sa
import psycopg2 as pg
from pandas.io.sql import read_sql

from sqlalchemy import create_engine
engine = create_engine('postgresql://iangow.me/crsp')

sql = "SELECT file_name, order_text FROM ct_orders.raw_text"

df = pd.read_sql(sa.text(sql), engine)


# Extract details of affected form type and date

def extract_details(order_text):
    import re
    regex = r"^.*excluded.*?(10-Q|10-K|Form.*?)\sfiled\s+(?:on\s)?(.*?\d{4}).*"
    # regex = r"excluded"
    matches = re.search(regex, order_text, flags=re.S)
    if matches:
        return matches

df['details'] = df['order_text'].apply(extract_details)

def form_type(detail_text):
    import re
    if detail_text:
        temp = detail_text.group(1)
        return re.sub(r"\n", " ", temp)

## Extract form type
df['form'] = df['details'].apply(form_type)

def convert_date(datetext):
    from datetime import datetime
    import re

    if datetext:
        try:
            datetext = re.sub(r"\n", " ", datetext)
            date = datetime.strptime(datetext, '%B %d, %Y')
            return date
        except:
            return None

# Extract form date
def form_date(detail_text):
    import re
    if detail_text:
        temp = detail_text.group(2)
        return convert_date(temp)

df['form_date'] = df['details'].apply(form_date)


# Get information on whether order grants or denies request

def check_regex(text, pattern):
    import re

    if re.findall(pattern, text, flags=re.S):
        return True
    else:
        return False

# df['order_type'] = df['order_text'].map(lambda x: re.findall(r"^.*ORDER\s+(\w+).*$", x, flags=re.S))
df['denied'] = df['order_text'].map(lambda x: check_regex(x, pattern=r"ORDER\s+DENYING"))
df['granted'] = df['order_text'].map(lambda x: check_regex(x, pattern=r"ORDER\s+GRANTING"))

# Get exhibits mentioned
def extract_exhibits(order_text):
    import re
    regex = r"[Ee]xhibit\s+[0-9][A-Z0-9a-z\(\)\.-]+"
    matches = re.findall(regex, order_text, flags=re.S)
    if matches:
        return matches

df['exhibits'] = df['order_text'].apply(extract_exhibits)

# Code to push data to PostgreSQL database

# Delete columns not needed any more
del df['order_text']
del df['details']

# Actually push data to PostgreSQL database
df.to_sql('processed_data_py', engine, schema="ct_orders",
         if_exists="replace", index=False)

# Do some database-related clean-up
res = engine.execute(
    """ALTER TABLE ct_orders.processed_data_py
    OWNER TO ct_orders_access""")
