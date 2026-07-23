"""
Simple Inference Chat — Web API

Routes chat requests to multiple backends (vLLM, Bedrock) based on
the model selected in the UI. See models/registry.py to add models.
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles

from models import registry
from models.router import BackendError, ModelNotFoundError, route_chat, route_chat_stream

app = FastAPI(title="Simple Inference Chat")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/api/models")
async def list_models():
    """Return all registered models."""
    return {"data": registry.list_models()}


@app.post("/api/chat")
async def chat(request: Request):
    """Route chat completions to the backend matching the selected model."""
    body = await request.json()
    stream = body.get("stream", True)

    try:
        if stream:
            return StreamingResponse(
                route_chat_stream(body),
                media_type="text/event-stream",
                headers={"Cache-Control": "no-cache", "Connection": "keep-alive"},
            )
        else:
            result = await route_chat(body)
            return result
    except ModelNotFoundError as e:
        return JSONResponse(status_code=404, content={"error": str(e)})
    except BackendError as e:
        return JSONResponse(
            status_code=e.status_code,
            content={"error": f"Backend error: {e.status_code}", "detail": e.detail},
        )
    except Exception as e:
        return JSONResponse(
            status_code=502,
            content={"error": "Failed to reach inference backend", "detail": str(e)},
        )


# Serve static frontend files
app.mount("/", StaticFiles(directory="public", html=True), name="static")
