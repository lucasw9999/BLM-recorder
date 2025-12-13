# key_classifier.py

import os
import json
import numpy as np
import re
from PIL import Image
import cv2

from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.callbacks import ModelCheckpoint
from tensorflow.keras import layers, models
import coremltools as ct

class KeyClassifier:
    """
    A KeyClassifier that:
      1) Reads an annotation_file (array of dicts, each with 'filename' + possibly 'key_name').
      2) For each sample, loads the image from 'image_dir', optionally crops ROI, then uses
         ImageDataGenerator to produce N augmented images.
      3) Collects all augmented images + labels in self.X, self.y
      4) Builds & trains a CNN, then exports it to Core ML as a classifier with VNClassificationObservation.

    Args:
        annotation_file (str): Path to the annotation JSON produced by your web tool.
        key_name (str): e.g. 'hla-direction' or 'spin-axis-direction' etc.
        roi (tuple): (x, y, w, h) in [0..1], if you want to crop a region from each image. 
                     If you don't need cropping, set it to (0,0,1,1) or ignore it.
        image_dir (str): Folder containing your images (PNG/JPG etc.).
        output_model_path (str): Where to save the .mlmodel file.
        image_size (tuple[int, int]): (width, height) for resizing each cropped image.
        aug_per_sample (int): How many new augmented images to generate per sample.
                              If 10, each original image yields 10 augmented copies.
    """

    def __init__(
        self,
        dataset_dir,
        dataset_version,
        key_name,
        roi,
        output_model_path,
        image_size=(64, 32),
        aug_per_sample=100
    ):
        self.dataset_dir = dataset_dir
        self.dataset_version = dataset_version
        self.key_name = key_name
        self.roi = roi  # (x, y, w, h) in [0..1] 
        self.output_model_path = os.path.join(output_model_path, dataset_version, key_name)
        self.image_size = image_size  # (width, height)
        self.aug_per_sample = aug_per_sample

        self.X = None
        self.y = None
        self.model = None

    def gather_data(self):
        """
        Reads annotation_file (JSON array). For each record:
         - Load & optionally crop the image to self.roi.
         - Generate self.aug_per_sample augmented images from that single base image.
         - Label = record[self.key_name] if it exists, else "None".
        Finally, shuffle & store in self.X and self.y.
        """

        # Prepare lists to hold X and y data
        X_list = []
        y_list = []

        # Prepare a Keras ImageDataGenerator with your chosen augmentations
        #    e.g. brightness, shifts, shear, zoom, no flips or rotations.
        datagen = ImageDataGenerator(
            width_shift_range=0.2,
            height_shift_range=0.2,
            brightness_range=[0.8, 1.3],
            shear_range=0.1,
            zoom_range=0.1,
            fill_mode="nearest"
        )

        # A dictionary to map textual label -> index
        label_to_idx = {}

        # Get all image dirs and annotation files
        def generate_version_list(version_str): # get all versions from this one back to v0
            match = re.match(r'v(\d+)', version_str)
            if match:
                num = int(match.group(1))
                return [f'v{i}' for i in range(num, -1, -1)]

        versions = generate_version_list(self.dataset_version)
        image_dirs = [os.path.join(self.dataset_dir, version) for version in versions]
        
        for image_dir in image_dirs:
            # Load data labels
            annotation_file = os.path.join(image_dir, "annotations.json")
            with open(annotation_file, "r", encoding="utf-8") as f:
                annotations = json.load(f)

            for record in annotations:
                filename = record.get("filename")
                if not filename:
                    continue  # skip if no filename
                filepath = os.path.join(image_dir, filename)
                if not os.path.isfile(filepath):
                    continue  # skip if file doesn't exist

                label = record[self.key_name] if self.key_name in record else "None"
                if label not in label_to_idx:
                    label_to_idx[label] = len(label_to_idx)
                label_idx = label_to_idx[label]

                # Load the image as color or grayscale (up to you)
                # For demonstration, let's do color via PIL -> convert to NumPy
                # If you prefer cv2, that's fine too.
                img = cv2.imread(filepath)

                # Crop to ROI if desired
                if self.roi != (0, 0, 1, 1):
                    img_h, img_w = img.shape[:2]
                    x_abs = int(self.roi[0] * img_w)
                    y_abs = int(self.roi[1] * img_h)
                    w_abs = int(self.roi[2] * img_w)
                    h_abs = int(self.roi[3] * img_h)
                    img = img[y_abs:y_abs + h_abs, x_abs:x_abs + w_abs]

                # Convert to grayscale
                gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

                # Normalize the grayscale image to range [0, 255]
                normalized_gray = cv2.normalize(gray, None, 0, 255, cv2.NORM_MINMAX)

                # Convert the normalized grayscale image back to a 3-channel color image
                color_image = cv2.cvtColor(normalized_gray.astype(np.uint8), cv2.COLOR_GRAY2BGR)

                # Resize the image
                img_resized = cv2.resize(color_image, (self.image_size[0], self.image_size[1]), interpolation=cv2.INTER_CUBIC)

                # Convert to NumPy array and expand dimensions to shape (1, h, w, channels)
                base_img = np.expand_dims(img_resized, axis=0)

                # 5) Generate self.aug_per_sample augmented images
                flow_iter = datagen.flow(base_img, batch_size=1)
                for _ in range(self.aug_per_sample):
                    aug_img = next(flow_iter)[0]  # shape: (h, w, channels)
                    X_list.append(aug_img)
                    y_list.append(label_idx)

        self.class_labels = list(label_to_idx.keys())

        # Convert lists to arrays
        self.X = np.array(X_list, dtype=np.float32)
        self.y = np.array(y_list, dtype=np.int32)

        # Shuffle
        indices = np.random.permutation(len(self.X))
        self.X = self.X[indices]
        self.y = self.y[indices]

        # Scale pixel values to [0..1]
        self.X /= 255.0

    def build_model(self):
        """
        Builds a small CNN that outputs len(self.class_labels) classes.
        We define an explicit Input layer to avoid the
        'do not pass input_shape to a layer' Keras warning.
        """
        num_classes = len(self.class_labels)

        # Keras expects (height, width, channels) for input_shape
        height = self.image_size[1]
        width = self.image_size[0]
        input_shape = (height, width, 3)  # 3 channels for color

        # A simple CNN
        self.model = models.Sequential([
            layers.Input(shape=input_shape),
            layers.Conv2D(32, (3, 3), activation='relu'),
            layers.MaxPooling2D((2, 2)),

            layers.Conv2D(64, (3, 3), activation='relu'),
            layers.MaxPooling2D((2, 2)),

            layers.Flatten(),
            layers.Dense(128, activation='relu'),
            layers.Dense(num_classes, activation='softmax')
        ])
        self.model.compile(
            optimizer='adam',
            loss='sparse_categorical_crossentropy',
            metrics=['accuracy']
        )

    def train(self, epochs=10, batch_size=32):
        """
        Trains the model on all augmented data in self.X/self.y.
        Uses validation_split=0.2 (20% of data).
        Saves the best checkpoint (by val_loss) to an .h5 file.
        Also saves a sidecar JSON with class labels, image size, etc.
        """
        if self.X is None or self.y is None or self.model is None:
            raise RuntimeError("Must call gather_data() and build_model() before train().")
        
        # 1) Prepare output paths
        #    e.g. if output_model_path = "./models/hla-direction",
        #    then the .h5 will be "./models/hla-direction.h5" 
        #    and the sidecar "./models/hla-direction.json"
        h5_model_path = self.output_model_path + ".h5"
        sidecar_path = self.output_model_path + ".json"

        os.makedirs(os.path.dirname(h5_model_path), exist_ok=True)

        # 2) Define a ModelCheckpoint callback that saves only the best model
        checkpoint_cb = ModelCheckpoint(
            filepath=h5_model_path,
            monitor="val_loss",
            mode="min",            # 'val_loss' is best when lower, so we use 'min'
            save_best_only=True,
            verbose=1
        )

        # 3) Train the model
        self.model.fit(
            self.X, self.y,
            epochs=epochs,
            batch_size=batch_size,
            validation_split=0.2,
            verbose=1,
            callbacks=[checkpoint_cb]
        )

        # 4) Load the best model weights
        self.model = models.load_model(h5_model_path)

        # 5) Write sidecar JSON with relevant metadata for future reference
        #    You can add or remove any fields you deem useful.
        sidecar_data = {
            "class_labels": self.class_labels,
            "image_size": self.image_size,
            "roi": self.roi,                 # If you used an ROI for cropping
            "key_name": self.key_name        # So you know what this model is for
            # Add any other info you'd like
        }
        with open(sidecar_path, "w", encoding="utf-8") as f:
            json.dump(sidecar_data, f, indent=2)

        print(f"[INFO] Best model saved to {h5_model_path}")
        print(f"[INFO] Sidecar metadata saved to {sidecar_path}")

    def export_coreml(self):
        """
        Converts the trained Keras model to a Core ML classifier
        that yields VNClassificationObservation in iOS.
        """
        if self.model is None:
            raise RuntimeError("No trained model to export. Call train() first.")

        # Use a classifier config with textual labels => VNClassificationObservation
        classifier_config = ct.ClassifierConfig(self.class_labels)

        height = self.image_size[1]
        width = self.image_size[0]
        # The model expects (batch, height, width, channels) => shape=(1, h, w, 3)
        ml_input = ct.ImageType(shape=(1, height, width, 3))

        coreml_model = ct.convert(
            self.model,
            inputs=[ml_input],
            classifier_config=classifier_config,
            source="tensorflow",
            convert_to="mlprogram",  # or "neuralnetwork"
            minimum_deployment_target=ct.target.iOS15
        )

        coreml_model_path = self.output_model_path + ".mlpackage"
        os.makedirs(os.path.dirname(coreml_model_path), exist_ok=True)
        coreml_model.save(coreml_model_path)
        print(f"[INFO] Saved Core ML model to {coreml_model_path}")
