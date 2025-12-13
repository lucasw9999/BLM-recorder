import os
import json
import argparse
from flask import Flask, render_template_string, request, redirect, url_for, send_from_directory

app = Flask(__name__)

# Define your radio options here
SCREEN_OPTIONS = ["Ball", "Club", "Both", "None"]
HLA_OPTIONS = ["L", "R", "None"]
SPIN_AXIS_OPTIONS = ["L", "R", "None"]
BALL_SPEED_UNITS = ["MPH", "KMH", "MPS", "None"]
CARRY_UNITS = ["YDS", "Meters", "None"]
PATH_DIR_OPTIONS = ["IN-OUT", "OUT-IN", "None"]
AOA_DIR_OPTIONS = ["UP", "DOWN", "None"]
CLUB_SPEED_UNITS = ["MPH", "KMH", "MPS", "None"]

# In-memory cache for annotations, so we don’t constantly rewrite the file
annotations_data = []
images_list = []
images_dir = None
ANNOTATIONS_FILENAME = "annotations.json"

# Language=jinja2
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Image Annotation Tool</title>
    <style>
        body {
            background-color: #2b2b2b;
            color: #e0e0e0;
            font-family: sans-serif;
            margin: 0;
            padding: 0;
        }
        .container {
            display: flex;
            flex-direction: row;
            width: 1080px; /* Fixed width container */
            margin: 40px auto;
        }
        .image-container {
            flex: 1;
            margin-right: 20px;
            max-width: 600px;
        }
        .image-container img {
            max-width: 100%;
            height: auto;
            display: block;
        }
        .form-container {
            flex: 1;
            display: flex;
            flex-direction: column;
        }
        .form-section {
            margin-bottom: 20px;
        }
        .buttons {
            margin-top: auto;
        }
        button {
            margin-right: 10px;
            padding: 8px 16px;
            cursor: pointer;
        }
        label {
            display: inline-block;
            margin-right: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Left: Image -->
        <div class="image-container">
            <img src="{{ url_for('serve_image', filename=current_image) }}" alt="Current Image">
        </div>

        <!-- Right: Annotations form -->
        <div class="form-container">
            <form id="annotationForm" action="{{ url_for('save_and_go', index=index) }}" method="POST">
                <input type="hidden" name="direction" id="directionInput" value="stay">

                <!-- Screen -->
                <div class="form-section">
                    <strong>Screen:</strong><br>
                    {% for opt in screen_options %}
                    <label>
                        <input type="radio" name="screen" value="{{ opt }}"
                            {% if annotations['screen'] == opt %}checked{% endif %}>
                        {{ opt }}
                    </label>
                    {% endfor %}
                </div>

                <!-- hla-direction -->
                <div class="form-section" id="hla-section">
                    <strong>HLA Direction:</strong><br>
                    {% for opt in hla_options %}
                    <label>
                        <input type="radio" name="hla-direction" value="{{ opt }}"
                            {% if annotations.get('hla-direction') == opt %}checked{% endif %}>
                        {{ opt }}
                    </label>
                    {% endfor %}
                </div>

                <!-- spin-axis-direction -->
                <div class="form-section" id="spin-axis-section">
                    <strong>Spin Axis Direction:</strong><br>
                    {% for opt in spin_axis_options %}
                    <label>
                        <input type="radio" name="spin-axis-direction" value="{{ opt }}"
                            {% if annotations.get('spin-axis-direction') == opt %}checked{% endif %}>
                        {{ opt }}
                    </label>
                    {% endfor %}
                </div>

                <!-- ball-speed-units -->
                <div class="form-section" id="ball-speed-section">
                    <strong>Ball Speed Units:</strong><br>
                    {% for opt in ball_speed_units %}
                    <label>
                        <input type="radio" name="ball-speed-units" value="{{ opt }}"
                            {% if annotations.get('ball-speed-units') == opt %}checked{% endif %}>
                        {{ opt }}
                    </label>
                    {% endfor %}
                </div>

                <!-- carry-units -->
                <div class="form-section" id="carry-section">
                    <strong>Carry Units:</strong><br>
                    {% for opt in carry_units %}
                    <label>
                        <input type="radio" name="carry-units" value="{{ opt }}"
                            {% if annotations.get('carry-units') == opt %}checked{% endif %}>
                        {{ opt }}
                    </label>
                    {% endfor %}
                </div>

                <!-- path-direction -->
                <div class="form-section" id="path-section">
                    <strong>Path Direction:</strong><br>
                    {% for opt in path_dir_options %}
                    <label>
                        <input type="radio" name="path-direction" value="{{ opt }}"
                            {% if annotations.get('path-direction') == opt %}checked{% endif %}>
                        {{ opt }}
                    </label>
                    {% endfor %}
                </div>

                <!-- aoa-direction -->
                <div class="form-section" id="aoa-section">
                    <strong>AOA Direction:</strong><br>
                    {% for opt in aoa_dir_options %}
                    <label>
                        <input type="radio" name="aoa-direction" value="{{ opt }}"
                            {% if annotations.get('aoa-direction') == opt %}checked{% endif %}>
                        {{ opt }}
                    </label>
                    {% endfor %}
                </div>

                <!-- club-speed-units -->
                <div class="form-section" id="club-speed-section">
                    <strong>Club Speed Units:</strong><br>
                    {% for opt in club_speed_units %}
                    <label>
                        <input type="radio" name="club-speed-units" value="{{ opt }}"
                            {% if annotations.get('club-speed-units') == opt %}checked{% endif %}>
                        {{ opt }}
                    </label>
                    {% endfor %}
                </div>

                <!-- Show filtered JSON fields -->
                <div class="form-section">
                    <strong>Extracted Data:</strong><br>
                    <table border="1" width="100%">
                        {% for key, value in json_data.items() %}
                            {% if key in ["Speed", "CarryDistance", "TotalSpin", "HLA", "VLA", "SpinAxis", "AngleOfAttack", "Efficiency", "Path"] %}  <!-- Filter fields -->
                                <tr>
                                    <td><strong>{{ key.replace("-", " ") | title }}</strong></td>
                                    <td>
                                        {% if value is number %}
                                            {{ value | round(2) }}  <!-- Round floating point numbers -->
                                        {% elif value is iterable and value is not string %}
                                            {{ value | map('round', 2) | list }}  <!-- Round lists of numbers -->
                                        {% else %}
                                            {{ value }}
                                        {% endif %}
                                    </td>
                                </tr>
                            {% endif %}
                        {% endfor %}
                    </table>
                </div>


                <!-- Action Buttons -->
                <div class="buttons">
                    <button type="submit" onclick="setDirection('stay')">Save</button>
                    <button type="button" onclick="setDirection('previous'); submitForm();">&laquo; Previous</button>
                    <button type="button" onclick="setDirection('next'); submitForm();">Next &raquo;</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        function updateVisibility() {
            const screenVal = document.querySelector('input[name="screen"]:checked').value;
            const ballSections = ["hla-section", "spin-axis-section", "ball-speed-section", "carry-section"];
            const clubSections = ["path-section", "aoa-section", "club-speed-section"];

            const showBall = (screenVal === "Ball" || screenVal === "Both");
            ballSections.forEach(id => {
                document.getElementById(id).style.display = showBall ? "block" : "none";
            });

            const showClub = (screenVal === "Club" || screenVal === "Both");
            clubSections.forEach(id => {
                document.getElementById(id).style.display = showClub ? "block" : "none";
            });
        }

        updateVisibility();
        document.querySelectorAll('input[name="screen"]').forEach(el => {
            el.addEventListener('change', updateVisibility);
        });

        function setDirection(dir) {
            document.getElementById("directionInput").value = dir;
        }

        function submitForm() {
            document.getElementById("annotationForm").submit();
        }

        // Keyboard navigation
        document.addEventListener('keydown', function(e) {
            if (e.key === "ArrowLeft") {
                setDirection('previous');
                submitForm();
            } else if (e.key === "ArrowRight") {
                setDirection('next');
                submitForm();
            }
        });
    </script>
</body>
</html>
"""


@app.route("/images/<path:filename>")
def serve_image(filename):
    return send_from_directory(images_dir, filename)

@app.route("/")
def home():
    # Always start with the first image
    return redirect(url_for('show_image', index=0))

@app.route("/image/<int:index>")
def show_image(index):
    if index < 0 or index >= len(images_list):
        # If out of bounds, redirect to first
        return redirect(url_for('show_image', index=0))

    current_image = images_list[index]
    # Find existing annotation or create default
    annotation = next((item for item in annotations_data if item["filename"] == current_image), None)
    if not annotation:
        annotation = {"filename": current_image, "screen": SCREEN_OPTIONS[0]}
        annotations_data.append(annotation)

    # --- NEW: Load any .json that matches the .png basename ---
    base_name, _ = os.path.splitext(current_image)  # e.g. "foo.png" -> ("foo", ".png")
    candidate_json_filename = base_name + ".json"   # "foo.json"
    candidate_json_path = os.path.join(images_dir, candidate_json_filename)


    json_data = {}  # Default to an empty dictionary
    if os.path.isfile(candidate_json_path):
        with open(candidate_json_path, "r", encoding="utf-8") as f:
            try:
                json_data = json.load(f)  # Correctly parse as dictionary
            except json.JSONDecodeError:
                json_data = {"error": "Invalid JSON format"}

    return render_template_string(
        HTML_TEMPLATE,
        current_image=current_image,
        index=index,
        screen_options=SCREEN_OPTIONS,
        hla_options=HLA_OPTIONS,
        spin_axis_options=SPIN_AXIS_OPTIONS,
        ball_speed_units=BALL_SPEED_UNITS,
        carry_units=CARRY_UNITS,
        path_dir_options=PATH_DIR_OPTIONS,
        aoa_dir_options=AOA_DIR_OPTIONS,
        club_speed_units=CLUB_SPEED_UNITS,
        annotations=annotation,
        json_data=json_data     # pass the loaded text into the template
    )


@app.route("/save_and_go/<int:index>", methods=["POST"])
def save_and_go(index):
    # Validate index
    if index < 0 or index >= len(images_list):
        return redirect(url_for('show_image', index=0))

    filename = images_list[index]
    screen_val = request.form.get("screen", SCREEN_OPTIONS[0])

    # Build a fresh annotation dict with only the relevant keys.
    new_annotation = {
        "filename": filename,
        "screen": screen_val
    }

    # If screen is "Ball" or "Both", store the ball fields
    if screen_val in ("Ball", "Both"):
        new_annotation["hla-direction"] = request.form.get("hla-direction", HLA_OPTIONS[0])
        new_annotation["spin-axis-direction"] = request.form.get("spin-axis-direction", SPIN_AXIS_OPTIONS[0])
        new_annotation["ball-speed-units"] = request.form.get("ball-speed-units", BALL_SPEED_UNITS[0])
        new_annotation["carry-units"] = request.form.get("carry-units", CARRY_UNITS[0])

    # If screen is "Club" or "Both", store the club fields
    if screen_val in ("Club", "Both"):
        new_annotation["path-direction"] = request.form.get("path-direction", PATH_DIR_OPTIONS[0])
        new_annotation["aoa-direction"] = request.form.get("aoa-direction", AOA_DIR_OPTIONS[0])
        new_annotation["club-speed-units"] = request.form.get("club-speed-units", CLUB_SPEED_UNITS[0])

    # Remove the old annotation for this file (if any) and replace with the new one
    for i, ann in enumerate(annotations_data):
        if ann["filename"] == filename:
            annotations_data.pop(i)
            break
    annotations_data.append(new_annotation)

    write_annotations_file()

    # Handle navigation (previous/next/stay)
    direction = request.form.get("direction", "stay")
    if direction == "next":
        new_index = index + 1
        if new_index >= len(images_list):
            new_index = len(images_list) - 1
        return redirect(url_for('show_image', index=new_index))
    elif direction == "previous":
        new_index = index - 1
        if new_index < 0:
            new_index = 0
        return redirect(url_for('show_image', index=new_index))
    else:
        # Stay on this image
        return redirect(url_for('show_image', index=index))

def write_annotations_file():
    """Write the in-memory annotations_data list to annotations.json in images_dir."""
    json_path = os.path.join(images_dir, ANNOTATIONS_FILENAME)
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(annotations_data, f, indent=2)

def load_annotations_file():
    """Load existing annotations.json if present, into annotations_data."""
    json_path = os.path.join(images_dir, ANNOTATIONS_FILENAME)
    if os.path.isfile(json_path):
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                return data
    return []

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--images_dir", type=str, required=True,
                        help="Path to directory containing .png images.")
    args = parser.parse_args()

    images_dir = args.images_dir
    if not os.path.isdir(images_dir):
        print(f"Error: Directory '{images_dir}' does not exist.")
        exit(1)

    # Gather all PNG images
    images_list = [f for f in os.listdir(images_dir) if f.lower().endswith(".png")]
    images_list.sort()

    # Load existing annotations if file exists
    annotations_data = load_annotations_file()

    # Start Flask app
    app.run(debug=True)
