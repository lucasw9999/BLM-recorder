import os
import uuid
import json
import cv2
import numpy as np

from flask import Flask, render_template, request, jsonify, send_from_directory
from werkzeug.utils import secure_filename

#from detect_screen import detect_screen

app = Flask(__name__)


def warp_perspective(image, points):
    # Ensure the points are ordered properly (top-left, top-right, bottom-right, bottom-left)
    ordered_points = np.array(sorted(points, key=lambda x: (x[1], x[0])))
    if ordered_points[1][0] < ordered_points[2][0]:  # Ensure the second is top-right
        ordered_points[1], ordered_points[2] = ordered_points[2], ordered_points[1]

    # Destination points for a fixed resolution/aspect ratio
    width = 900
    height = 450
    dst_points = np.array([[0, 0], [width, 0], [width, height], [0, height]], dtype=np.float32)

    # Get the transformation matrix and warp the perspective
    M = cv2.getPerspectiveTransform(points.astype(np.float32), dst_points)
    warped = cv2.warpPerspective(image, M, (width, height))
    return warped

def sort_points_clockwise(points):
    """
    Sort the four points in clockwise order, with the first point being the closest to (0, 0).
    Args:
        points (numpy.ndarray): 4x2 array of points.
    Returns:
        numpy.ndarray: Sorted 4x2 array of points.
    """
    # Calculate the centroid of the points
    center = np.mean(points, axis=0)

    # Sort points based on their angle with respect to the centroid
    def angle_from_center(point):
        return np.arctan2(point[1] - center[1], point[0] - center[0])

    points = sorted(points, key=angle_from_center)

    # Find the point closest to (0, 0) and rotate the points so that it comes first
    closest_index = np.argmin(np.linalg.norm(points, axis=1))
    points = np.roll(points, -closest_index, axis=0)

    return np.array(points, dtype=np.int32)

def detect_screen(image):
    """
    Detect the screen in the given RGB image and return its 4-point polygon.
    Args:
        image (numpy.ndarray): Input RGB image.
    Returns:
        numpy.ndarray: 4-point polygon of the detected screen, or None if no screen is found.
    """
    # Convert the image to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Normalize the image to the range 0-255
    normalized = cv2.normalize(gray, None, 0, 255, cv2.NORM_MINMAX)

    # Apply Otsu's thresholding
    _, thresh = cv2.threshold(normalized, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # Create an elliptical kernel and apply morphological opening
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))
    opened = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)

    # Find contours (only external contours)
    contours, _ = cv2.findContours(opened, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Iterate through the contours to approximate the screen
    for contour in contours:
        # Approximate the contour to a polygon
        epsilon = 0.02 * cv2.arcLength(contour, True)  # Adjust epsilon if needed
        approx = cv2.approxPolyDP(contour, epsilon, True)

        # Check if the approximated polygon has 4 points
        if len(approx) == 4:
             # Reshape the points to (4, 2) and convert to np.int32
            points = approx.reshape((4, 2))
            # Ensure points are sorted clockwise with the first point closest to (0, 0)
            return sort_points_clockwise(points)

    return None  # No valid screen contour found

def detect_and_warp(image):
    points = detect_screen(image)
    warped = warp_perspective(image, points)
    return warped

# ----------------------------------------------------------------
# Routes
# ----------------------------------------------------------------

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/process_image", methods=["POST"])
def process_image():
    file = request.files['image']
    filename = secure_filename(file.filename)
    file.save(filename)

    img = cv2.imread(filename)
    warped = detect_and_warp(img)

    warped_filename = f"warped_{uuid.uuid4().hex}.jpg"
    cv2.imwrite(warped_filename, warped)

    return jsonify({"filename": warped_filename})

@app.route("/uploads/<path:filename>")
def uploaded_file(filename):
    return send_from_directory(".", filename)

@app.route("/save_json", methods=["POST"])
def save_json():
    """
    Expects JSON of the form:
    {
      "filename": "annotations.json",
      "rects": [
        {
          "name": "Box 1",
          "rect": [x, y, w, h],
          "format": ["hello", "goodbye"]
        },
        ...
      ]
    }
    """
    data = request.json
    rects = data.get("rects", [])
    output_filename = data.get("filename", "output.json")

    with open(output_filename, "w") as f:
        json.dump(rects, f, indent=2)

    return jsonify({"status": "success", "message": f"Saved to {output_filename}"})


@app.route("/load_json", methods=["POST"])
def load_json():
    """
    Expects JSON of the form:
    {
      "filename": "annotations.json"
    }
    Returns the array of rects:
    [
      {
        "name": "Box 1",
        "rect": [x, y, w, h],
        "format": ["hello", "goodbye"]
      },
      ...
    ]
    """
    data = request.json
    input_filename = data.get("filename", "")

    if not os.path.exists(input_filename):
        return jsonify({"status": "error", "message": "File not found"}), 404

    with open(input_filename, "r") as f:
        rects = json.load(f)

    return jsonify({"status": "success", "rects": rects})

if __name__ == "__main__":
    app.run(debug=True)
