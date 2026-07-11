import json

with open("policies.json") as f:
    data = json.load(f)

for p in data:
    if "Isolated" in p.get("name", ""):
        print(f"Index: {p.get('index')} - {p.get('name')} - Action: {p.get('action')}")
