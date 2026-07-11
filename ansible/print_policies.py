import json

with open("policies.json") as f:
    data = json.load(f)

for i, p in enumerate(data.get("data", data)):
    name = p.get("name")
    action = p.get("action")
    print(f"{i}: {name} ({action})")
