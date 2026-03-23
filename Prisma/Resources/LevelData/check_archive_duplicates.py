import json

def load_json(path):
    with open(path, 'r') as f:
        return json.load(f)

local_events = load_json("archive_events.json")
daily_events = load_json("archive_events_daily.json")

local_dates = {f"{e['day']}-{e['month']}-{e['year']}": e for e in local_events}

duplicates = []
for d in daily_events:
    date_key = f"{d['day']}-{d['month']}-{d['year']}"
    if date_key in local_dates:
        duplicates.append((d, local_dates[date_key]))
        
for daily, local in duplicates:
    print(f"DUPLICATE - Day {daily['day']}/{daily['month']}/{daily['year']}")
    print(f"  Local: {local['event']} (Hint: {local['hint']})")
    print(f"  Daily: {daily['event']} (Hint: {daily['hint']})")
    print()
