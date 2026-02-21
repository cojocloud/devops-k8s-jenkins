FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy requirements and install in one layer
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all application code and templates in one layer
COPY app/main.py app/templates ./  

# Run the FastAPI app
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]