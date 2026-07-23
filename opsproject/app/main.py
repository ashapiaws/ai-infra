from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from typing import Optional
from datetime import datetime
from interfaces.query_engine import QueryEngine
from interfaces.storage import StorageService
from implementations.athena_query import AthenaQueryEngine
from implementations.s3_storage import S3StorageService

app = FastAPI(title="Data Query API")

# Initialize services
query_engine: QueryEngine = AthenaQueryEngine()
storage_service: StorageService = S3StorageService()


@app.get("/")
async def root():
    return {"message": "Data Query API"}


@app.post("/query")
async def execute_query(query: str, database: str = "default"):
    """Execute a query using the configured query engine"""
    try:
        result = await query_engine.execute_query(query, database)
        return {"status": "success", "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/upload")
async def upload_data(
    bucket: str,
    key: str,
    file: UploadFile = File(...),
    description: Optional[str] = Form(None),
    tags: Optional[str] = Form(None),
    author: Optional[str] = Form(None)
):
    """Upload a file to storage with optional metadata"""
    try:
        data = await file.read()
        
        # Parse tags if provided
        tag_list = [tag.strip() for tag in tags.split(",")] if tags else []
        
        # Prepare metadata for storage
        metadata = {
            "description": description,
            "author": author,
            "tags": tag_list,
            "filename": file.filename,
            "content_type": file.content_type
        }
        
        location = await storage_service.upload(bucket, key, data, metadata)
        
        return {
            "status": "success",
            "location": location,
            "filename": file.filename,
            "content_type": file.content_type,
            "size": len(data),
            "uploaded_at": datetime.utcnow().isoformat(),
            "metadata": {
                "description": description,
                "tags": tag_list,
                "author": author
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
