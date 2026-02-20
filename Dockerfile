FROM python:3.9-slim

WORKDIR /code

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade -r requirements.txt

COPY main.py form.html ./

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80", "--loop", "asyncio"]
