# auto_annotator.py

import os
import json
from PIL import Image
from key_inference import KeyInference  # or whatever file you keep the KeyInference class in
import argparse

KEYS = {
    "hla-direction", # screen: ball
    "spin-axis-direction", # screen: ball
    "ball-speed-units", # screen: ball
    "carry-units", # screen: ball
    "path-direction", # screen: club
    "aoa-direction", # screen: club
    "club-speed-units", # screen: club
}

def get_screen_value(annotation_record):
    ball_screen = False
    club_screen = False

    if (annotation_record["hla-direction"] != "None" or
        annotation_record["spin-axis-direction"] != "None" or
        annotation_record["ball-speed-units"] != "None" or
        annotation_record["carry-units"] != "None"):
        ball_screen = True

    if (annotation_record["path-direction"] != "None" or
        annotation_record["aoa-direction"] != "None" or
        annotation_record["club-speed-units"] != "None"):
        club_screen = True

    if ball_screen and club_screen:
        return "Both"
    elif ball_screen:
        return "Ball"
    elif club_screen:
        return "Club"
    else:
        return "None"

class AutoAnnotator:
    """
    Loads KeyInference objects for each key from a given model directory,
    then applies them to all images in a dataset folder to produce
    an auto-generated annotations.json.
    """

    def __init__(self, keys, model_path):
        """
        Args:
            keys (iterable[str]): The set of keys, e.g. [
              'hla-direction', 'spin-axis-direction', 'ball-speed-units', ...
            ]
            model_path (str): Path to the folder containing <key>.h5 and <key>.json sidecars.
        """
        self.keys = keys
        self.model_path = model_path

        # Load one KeyInference model per key
        self.classifiers = {}
        for key_name in self.keys:
            # We assume your trained models are named something like "hla-direction.h5"
            # with a sidecar "hla-direction.json"
            h5_model_filename = f"{key_name}.h5"
            h5_model_path = os.path.join(self.model_path, h5_model_filename)
            if not os.path.isfile(h5_model_path):
                raise FileNotFoundError(f"Missing model for {key_name} at {h5_model_path}")

            print(f"[INFO] Loading model for key '{key_name}' from {h5_model_path}")
            self.classifiers[key_name] = KeyInference(h5_model_path)

    def auto_annotate(self, dataset_dir):
        """
        Iterates over images in dataset_dir, runs each classifier,
        and saves the resulting predictions to <dataset_dir>/annotations.json.
        """
        # Gather all images in dataset_dir (e.g. .png, .jpg, etc.)
        all_images = [
            f for f in os.listdir(dataset_dir)
            if f.lower().endswith(".png") or f.lower().endswith(".jpg")
        ]
        all_images.sort()

        annotations = []
        for filename in all_images:
            filepath = os.path.join(dataset_dir, filename)
            if not os.path.isfile(filepath):
                continue

            # Create an annotation record for this image

            # Load the image
            temp_record = {}
            with Image.open(filepath).convert("RGB") as pil_image:
                # For each key, run inference
                for key_name, classifier in self.classifiers.items():
                    predicted_label = classifier.predict_class(pil_image)
                    temp_record[key_name] = predicted_label

            screen = get_screen_value(temp_record)
            record = {
                "filename": filename,
                "screen": screen
            }
            if screen == "Ball" or screen == "Both":
                record["hla-direction"] = temp_record["hla-direction"]
                record["spin-axis-direction"] = temp_record["spin-axis-direction"]
                record["ball-speed-units"] = temp_record["ball-speed-units"]
                record["carry-units"] = temp_record["carry-units"]
            elif screen == "Club" or screen == "Both":
                record["path-direction"] = temp_record["path-direction"]
                record["aoa-direction"] = temp_record["aoa-direction"]
                record["club-speed-units"] = temp_record["club-speed-units"]

            annotations.append(record)


        # Save to "annotations.json" in dataset_dir
        output_path = os.path.join(dataset_dir, "annotations.json")
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(annotations, f, indent=2)

        print(f"[INFO] Wrote auto-generated annotations to {output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=str, required=True, help="Model verison to use for annotations (i.e. 'v0').")
    parser.add_argument("--dataset", type=str, required=True, help="Dataset version to annotate (i.e. 'v1').")
    args = parser.parse_args()

    model_path = os.path.join("./models/", args.model) # Version of models we will use
    dataset_path = os.path.join("./dataset/", args.dataset) # Version of dataset we will auto-nnotate

    auto = AutoAnnotator(
        keys=KEYS,
        model_path=model_path
    )
    auto.auto_annotate(dataset_path)