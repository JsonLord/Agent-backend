#!/bin/bash

echo "Starting application..."
python run_ui.py --host 0.0.0.0 --port 7860 --dockerized=true
