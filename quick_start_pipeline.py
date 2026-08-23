import dlt

data = [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]

pipeline = dlt.pipeline(pipeline_name="quick_start", destination="duckdb", dataset_name="mydata")
load_info = pipeline.run(data, table_name="users")

print(load_info)

# get the dataset
dataset = pipeline.dataset()

# get the user relation
table = dataset.users

# query the full table as dataframe
print(table.df())

# query the first 10 rows as arrow table
print(table.limit(10).arrow())
