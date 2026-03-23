import json

def load_json(path):
    with open(path, 'r') as f:
        return json.load(f)

def save_json(path, data):
    with open(path, 'w') as f:
        json.dump(data, f, indent=4)

daily_events = load_json("archive_events_daily.json")

# Replacements for the 3 overlaps
replacements = {
    "14-12-1911": {
        "day": 12, "month": 12, "year": 1901,
        "event": "First transatlantic radio signal",
        "hint": "Guglielmo Marconi received the letter 'S' sent across the ocean in Morse code."
    },
    "26-2-1993": {
        "day": 26, "month": 2, "year": 1935,
        "event": "Radar demonstrated",
        "hint": "Robert Watson-Watt demonstrated an early radio-based detection system."
    },
    "14-7-2015": {
        "day": 14, "month": 7, "year": 1789,
        "event": "Storming of the Bastille",
        "hint": "Parisians captured a medieval fortress, igniting a revolution."
    }
}

for i, d in enumerate(daily_events):
    date_key = f"{d['day']}-{d['month']}-{d['year']}"
    if date_key in replacements:
        r = replacements[date_key]
        r["id"] = d["id"] # Keep original ID
        daily_events[i] = r
        print(f"Replaced {date_key}")

# Now add empty funFact to ALL events
for e in daily_events:
    if "funFact" not in e: e["funFact"] = "Did you know? [Fact needed]"

local_events = load_json("archive_events.json")
for e in local_events:
    if "funFact" not in e: e["funFact"] = "Did you know? [Fact needed]"

save_json("archive_events_daily.json", daily_events)
save_json("archive_events.json", local_events)
print("Saved both files with funFact fields added.")
