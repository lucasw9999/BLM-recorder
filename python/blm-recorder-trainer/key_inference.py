import os
import json
import numpy as np
from PIL import Image
import cv2 

from tensorflow.keras.models import load_model

class KeyInference:
    """
    Loads a Keras .h5 model and its sidecar JSON, then crops images to the ROI,
    returning a predicted class label.

    We assume:
      - The sidecar file has the same base name as h5_model_path, but with '.json' extension.
      - The sidecar includes "roi", "key_name", "class_labels", "image_size".
    """

    def __init__(self, h5_model_path):
        # 1) Check that the .h5 exists
        if not os.path.isfile(h5_model_path):
            raise FileNotFoundError(f"Cannot find model at {h5_model_path}")

        # 2) Derive sidecar path, e.g. './models/hla-direction.h5' => './models/hla-direction.json'
        sidecar_path = os.path.splitext(h5_model_path)[0] + ".json"
        if not os.path.isfile(sidecar_path):
            raise FileNotFoundError(f"Cannot find sidecar JSON at {sidecar_path}")

        # 3) Load sidecar metadata
        with open(sidecar_path, "r", encoding="utf-8") as f:
            sidecar_data = json.load(f)

        # 4) Extract fields from sidecar
        self.roi = tuple(sidecar_data.get("roi", (0, 0, 1, 1)))
        self.key_name = sidecar_data.get("key_name", "")
        self.class_labels = sidecar_data.get("class_labels", [])
        self.image_size = tuple(sidecar_data.get("image_size", (64, 32)))

        # 5) Load the Keras model
        self.model = load_model(h5_model_path)

    def predict_class_from_image_file(self, image_path):
        pil_image = Image.open(image_path)
        return self.predict_class(pil_image)

    def predict_class(self, pil_image):
        img = np.array(pil_image)  # Convert PIL to NumPy array
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR) 

        # Get image dimensions
        img_h, img_w = img.shape[:2]

        # 1) Calculate absolute pixel coordinates from the relative ROI
        x_abs = int(self.roi[0] * img_w)
        y_abs = int(self.roi[1] * img_h)
        w_abs = int(self.roi[2] * img_w)
        h_abs = int(self.roi[3] * img_h)

        # 2) Crop
        cropped = img[y_abs:y_abs + h_abs-1, x_abs:x_abs + w_abs-1]

        gray = cv2.cvtColor(cropped, cv2.COLOR_BGR2GRAY)

        # Normalize the grayscale image to range [0, 255]
        normalized_gray = cv2.normalize(gray, None, 0, 255, cv2.NORM_MINMAX)

        # Convert the normalized grayscale image back to a 3-channel color image
        cropped_normalized = cv2.cvtColor(normalized_gray.astype(np.uint8), cv2.COLOR_GRAY2BGR)

        # 3) Resize using cubic interpolation
        resized = cv2.resize(cropped_normalized, self.image_size, interpolation=cv2.INTER_CUBIC)

        # 4) Convert to float array and normalize to [0,1] range
        arr = resized.astype(np.float32) / 255.0

        # 5) Expand dimensions to make it (1, H, W, C) for model input
        arr = np.expand_dims(arr, axis=0)

        # 5) Run inference
        preds = self.model.predict(arr)
        idx = np.argmax(preds[0])
        # 6) Map index to label
        if idx < len(self.class_labels):
            return self.class_labels[idx]
        else:
            return "Unknown"

    def __repr__(self):
        return f"<KeyInference key='{self.key_name}', roi={self.roi}, model={self.model.name}>"
