FROM python:3.9.1-slim-buster

RUN pip install pandas

COPY validate.py /usr/local/bin/.
COPY score.py /usr/local/bin/.

RUN chmod +x /usr/local/bin/*.py
