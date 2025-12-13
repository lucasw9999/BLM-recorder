import os
import numpy as np
import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras import layers, models
import coremltools as ct
import cv2

# Configuration
IMG_SIZE = (50, 50)
NUM_AUGMENTED_IMAGES = 1000
DATASET_PATH = "direction-dataset"
BATCH_SIZE = 32

# Data Augmentation
datagen = ImageDataGenerator(
    width_shift_range=0.2,
    height_shift_range=0.2,
    brightness_range=[0.5, 1.5],
    shear_range=0.2,
    zoom_range=0.2,
    fill_mode="nearest"
)

# Prepare Training Data
def load_and_augment_images(class_name):
    img_path = os.path.join(DATASET_PATH, f"{class_name}.png")
    if not os.path.exists(img_path):
        raise FileNotFoundError(f"No image found for class '{class_name}' at {img_path}")
    
    img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)
    img = cv2.resize(img, IMG_SIZE)
    img = np.expand_dims(img, axis=-1)
    img = np.expand_dims(img, axis=0)
    
    augmented_images = []
    for _ in range(NUM_AUGMENTED_IMAGES):
        augmented = next(datagen.flow(img, batch_size=1))[0].astype(np.uint8)
        augmented_images.append(augmented)
    
    return np.array(augmented_images)

# Load Data
classes = [f.split(".")[0] for f in os.listdir(DATASET_PATH) if f.endswith(".png")]
X_train, y_train = [], []

for idx, class_name in enumerate(classes):
    augmented_images = load_and_augment_images(class_name)
    X_train.append(augmented_images)
    y_train.extend([idx] * NUM_AUGMENTED_IMAGES)

X_train = np.vstack(X_train)
y_train = np.array(y_train)

# Shuffle Data
indices = np.random.permutation(len(X_train))
X_train, y_train = X_train[indices], y_train[indices]

# Normalize
X_train = X_train.astype("float32") / 255.0

# Define Model
model = models.Sequential([
    layers.Input(shape=(*IMG_SIZE, 1)),
    layers.Conv2D(32, (3, 3), activation='relu'),
    layers.MaxPooling2D((2, 2)),
    layers.Conv2D(64, (3, 3), activation='relu'),
    layers.MaxPooling2D((2, 2)),
    layers.Flatten(),
    layers.Dense(128, activation='relu'),
    layers.Dense(len(classes), activation='softmax')
])

model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

# Train Model
model.fit(X_train, y_train, epochs=10, batch_size=BATCH_SIZE, validation_split=0.2)

model.save("text_classifier.keras")

# Load the Keras model
keras_model = tf.keras.models.load_model("text_classifier.keras")

# Define input type
input_type = ct.ImageType(shape=(1, *IMG_SIZE, 1), color_layout=ct.colorlayout.GRAYSCALE)

input_type = ct.ImageType(
    shape=(1, *IMG_SIZE, 1),  # Batch size of 1, 50x50 image with 1 channel
    color_layout=ct.colorlayout.GRAYSCALE  # Use the GRAYSCALE color layout
)

# Convert to Core ML
coreml_model = ct.convert(
    keras_model,
    inputs=[input_type],
    source="tensorflow",
    convert_to="neuralnetwork",
)


# Save Core ML model
class_labels = ["L", "R", "None"]  # Replace with actual labels
coreml_model.user_defined_metadata["classes"] = ",".join(class_labels)

coreml_model.save("text_classifier.mlmodel")

print("✅ Core ML model saved successfully as text_classifier.mlmodel")