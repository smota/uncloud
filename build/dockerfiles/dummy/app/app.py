# app.py
from flask import Flask
import os

# Initialize the Flask application
app = Flask(__name__)

# Get the port number from the environment variable, default to 8080
# This makes the port configurable.
port = int(os.environ.get("PORT", 8080))

@app.route('/')
def hello_world():
    return 'Hello, World from inside the Docker container!'

if __name__ == '__main__':
    # 0.0.0.0 makes the app accessible from outside the container
    app.run(debug=True, host='0.0.0.0', port=port)