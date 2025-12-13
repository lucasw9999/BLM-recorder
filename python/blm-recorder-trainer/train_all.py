# train_all_keys.py

import json
import os
from train_classifier import KeyClassifier
import argparse

KEYS = {
    "hla-direction",
    "spin-axis-direction",
    "ball-speed-units",
    "carry-units",
    "path-direction",
    "aoa-direction",
    "club-speed-units",
}

DATASET_DIR = "./dataset"
ROI_ANNOTATION_DIR = "../blm-recorder-annotator"
ball_roi_json = os.path.join(ROI_ANNOTATION_DIR, "annotations-ball.json")
club_roi_json = os.path.join(ROI_ANNOTATION_DIR, "annotations-club.json")
screen_roi_json = os.path.join(ROI_ANNOTATION_DIR, "annotations-screen.json")

MODEL_PATH="./models"

# We'll show an example for how you might load the ROI from your attached JSON files.
# For instance, in "annotations-ball.json", we see something like:
#   { "name": "hla-direction", "rect": [0.89625, 0.2065625, 0.07, 0.175], ... }
# Or in "annotations-club.json", we might have path-direction, etc.
# We can parse each file and create a dictionary from 'name' to 'rect'.

def load_rois_from_file(json_path):
    """
    Returns a dict: { key_name: (x, y, w, h), ... }
    """
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    rois_dict = {}
    for item in data:
        kname = item["name"]  # e.g. "hla-direction"
        rect = item["rect"]   # e.g. [0.89625, 0.2065625, 0.07, 0.175]
        rois_dict[kname] = tuple(rect)  # convert to a tuple
    return rois_dict

def main(dataset_version):
    # Paths to your ROI JSON files
    # (you mentioned 3 files for ball/club/screen but let's just load them all
    #  and combine them into one dictionary keyed by name).

    # Load them
    ball_rois = load_rois_from_file(ball_roi_json)
    club_rois = load_rois_from_file(club_roi_json)
    screen_rois = load_rois_from_file(screen_roi_json)
    # Combine them:
    all_rois = {**ball_rois, **club_rois, **screen_rois}

    # Create an output folder for the .mlmodel files
    os.makedirs("models", exist_ok=True)

    # For each key, we:
    # 1) Look up the ROI
    # 2) Create a KeyClassifier
    # 3) gather_data -> build_model -> train -> export_coreml
    for key_name in KEYS:
        # Find the ROI for this key (or default if missing)
        roi = all_rois.get(key_name)  # fallback is the full image

        # Create the classifier object
        classifier = KeyClassifier(
            dataset_dir=DATASET_DIR,
            dataset_version=dataset_version,
            key_name=key_name,
            roi=roi,
            output_model_path=MODEL_PATH,
            image_size=(64, 32)  # or customize per key if needed
        )

        # Gather data
        classifier.gather_data()

        # Build model
        classifier.build_model()

        # Train
        classifier.train(epochs=10, batch_size=32)

        # Export
        classifier.export_coreml()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=str, required=True, help="Dataset version to train (i.e. 'v1').")
    args = parser.parse_args()
    
    main(args.dataset)

