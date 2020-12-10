import os
import pymongo
import json
import sys
from datetime import datetime, timedelta

client = pymongo.MongoClient(os.getenv("MATSCHOLAR_PROD_HOST"),
                             username=os.getenv("MATSCHOLAR_PROD_USER"),
                             password=os.getenv("MATSCHOLAR_PROD_PASS"),
                             authSource=os.getenv("MATSCHOLAR_PROD_DB"))

db = client[os.getenv("MATSCHOLAR_PROD_DB")]

# if sys.argv and sys.argv[1] == "1":
#     entries = db.entries_vespa_upload.find({})
# elif sys.argv and sys.argv[1] == "2":
#     entries = db.entries_vespa_upload.find({"fields.timestamp":{"$gt":(datetime.now() - timedelta(7)).timestamp()}})
# else:
#     entries = db.entries_vespa_upload.find({"synced": False})

entries = db.entries_entities.find({}).limit(10000)

key_dict = {"MAT": "materials",
            "SPL": "phase_labels",
            "CMT": "characterization_methods",
            "PRO": "properties",
            "SMT": "synthesis_methods",
            "APL": "applications",
            "DSC": "descriptors",
            "MAT_clean": "materials_clean"
            }

with open("feed-file-temp.json", "w") as file:
    ids = []
    for entry in entries:
        if not "year" in entry:
            # 5 documents in db don't have a year. Manually checked and they all are from 2016
            entry["year"] = "2016"

        delkeys = []

        entry["id"] = str(entry["_id"])
        ids.append(entry["_id"])
        delkeys.append("_id")

        if "issn" in entry:
            delkeys.append("issn")


        for key in list(entry.keys()):
            if "summary" in key:
                delkeys.append(key)
            if key in key_dict:
                entry[key_dict[key]] = entry[key]
                delkeys.append(key)

        entry["timestamp"] = int(datetime(int(entry["year"]), 1, 1).timestamp())

        entry["year"] = str(entry["year"])

        for key in delkeys:
            del entry[key]

        file.write(json.dumps(entry))
        file.write("\n")

# db.entries_vespa_upload.update_many({"_id": {"$in": ids}}, {"$set": {"synced":True}})