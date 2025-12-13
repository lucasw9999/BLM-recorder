
This folder contains several python helpers for annotating data and training classifiers/models. Each has a different requirements file, make sure to create a venv and `pip install -r requirements.txt` before following the instructions below.

### blm-recorder-annotator
Run `annotator.py` and open the link shown in the console. Use this tool to annotate the BLM recorder interface(s), which produces {annotations-ball,annotations-ball,annotations-screen}.json. These should all be copied into the xcode project if modified.


### blm-recorder-trainer
This folder uses captured images from the BLM recorder app to train classifiers for certain parts of the screen (like L/R/UP/DOWN/IN-OUT/OUT-IN, etc). Full usage instructions below:

- Create a venv with python 3.9 and install the reqs. 3.9 is important because soem of the dependencies do not support newer versions.
```
python3.9 -m venv .venv --prompt ${PWD##*/} && source .venv/bin/activate
pip install -r requirements.txt
```

- Grab all images from the BLM recorder app (must be running on the phone). This downloads them to "downloaded_images/"
```
download_pngs.py # Make sure to set the IP address in the file, which is shown in the BLM recorder logs at startup
```

- Move the downloaded_images folder to dataset/vX where X is the next version of the dataset (i.e. v0, v1, v2, ...)

- Run the auto annotator to help speed up the annotation process
```
python auto_annotator.py --model vY --dataset vX # Where Y typically is X-1
```

- Check and correct any of the annotations:
```
python annotation_tool.py --images_dir dataset/vX
# Open a browser to http://127.0.0.1:5000
```

- Train the models
```
python train_all.py --dataset vX
```

- This outputs the models to `./models/vX/`, which can then be copied into the xcode project

### ballflight
Run `train_trajectory_models.py` to train new predictors for total distance, offline distance, and apex height. The training data is in `trajectory-data.csv` and was produced by inputting random shots into https://trajectory.flightscope.com/.