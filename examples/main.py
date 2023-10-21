import os
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from redis import Redis

app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

REDIS_HOST = os.environ.get('REDIS_HOST')
REDIS_PORT = os.environ.get('REDIS_PORT')
REDIS_PASS = os.environ.get('REDIS_PASS')
redis = Redis(host=REDIS_HOST, port=REDIS_PORT, password=REDIS_PASS)

@app.get('/', response_class=HTMLResponse)
async def hello(request: Request):
    redis.incr('hits')
    counter = str(redis.get('hits'), 'utf-8')
    return templates.TemplateResponse("index.html", {"request": request, "counter": counter})