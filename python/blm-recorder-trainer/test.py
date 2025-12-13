from key_inference import KeyInference

hla = KeyInference("./models/v1/hla-direction.h5")
print(hla.predict_class_from_image_file("/Users/kevin/Desktop/20250314_1926-0000-ball.png"))