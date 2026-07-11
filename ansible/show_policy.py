import json

with open("policies.json") as f:
    data = json.load(f)

for p in data:
    if p.get("name") == "Server to Talos API":
        print(json.dumps(p, indent=2))
