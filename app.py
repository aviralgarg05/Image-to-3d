import os

# Install system-level dependencies before torchmcubes
os.system("apt-get update && apt-get install -y cmake ninja-build libomp-dev")

# Install torchmcubes manually
os.system("pip install --no-cache-dir git+https://github.com/tatsy/torchmcubes.git")

import logging
import time
import torch
import numpy as np
from flask import Flask, request, jsonify, send_file
from PIL import Image
import rembg
import tempfile

from tsr.system import TSR
from tsr.utils import remove_background, resize_foreground, save_video
from tsr.bake_texture import bake_texture

# Initialize Flask app
app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)

# Load the model
device = "cuda:0" if torch.cuda.is_available() else "cpu"
model = TSR.from_pretrained("stabilityai/TripoSR", config_name="config.yaml", weight_name="model.ckpt")
model.to(device)

# Helper function to process image
def process_image(image_path, remove_bg=True, foreground_ratio=0.85):
    image = Image.open(image_path).convert("RGB")
    if remove_bg:
        rembg_session = rembg.new_session()
        image = remove_background(image, rembg_session)
        image = resize_foreground(image, foreground_ratio)
        image = np.array(image).astype(np.float32) / 255.0
        image = image[:, :, :3] * image[:, :, 3:4] + (1 - image[:, :, 3:4]) * 0.5
        image = Image.fromarray((image * 255.0).astype(np.uint8))
    return image

@app.route("/generate-3d", methods=["POST"])
def generate_3d():
    try:
        # Check if the request has an image file
        if "image" not in request.files:
            return jsonify({"error": "No image file provided"}), 400
        
        file = request.files["image"]
        temp_input = tempfile.NamedTemporaryFile(delete=False, suffix=".png")
        file.save(temp_input.name)

        # Process the image
        image = process_image(temp_input.name, remove_bg=True)

        # Run the model
        with torch.no_grad():
            scene_codes = model([image], device=device)

        # Extract the mesh
        meshes = model.extract_mesh(scene_codes, has_vertex_color=True, resolution=256)


        # Save the mesh file
        temp_output = tempfile.NamedTemporaryFile(delete=False, suffix=".obj")
        meshes[0].export(temp_output.name)

        # Return the file as a response
        return send_file(temp_output.name, as_attachment=True, download_name="3d_model.obj")


    except Exception as e:
        logging.error(str(e))
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
