from abc import ABC, abstractmethod
from typing import Optional, BinaryIO


class StorageService(ABC):
    """Abstract interface for object storage operations"""
    
    @abstractmethod
    async def upload(
        self, 
        bucket: str, 
        key: str, 
        data: bytes,
        metadata: Optional[dict] = None
    ) -> str:
        """
        Upload data to storage
        
        Args:
            bucket: Bucket/container name
            key: Object key/path
            data: Binary data to upload
            metadata: Optional metadata tags
            
        Returns:
            Location URI of uploaded object
        """
        pass
    
    @abstractmethod
    async def download(self, bucket: str, key: str) -> bytes:
        """Download data from storage"""
        pass
    
    @abstractmethod
    async def delete(self, bucket: str, key: str) -> bool:
        """Delete an object from storage"""
        pass
    
    @abstractmethod
    async def list_objects(self, bucket: str, prefix: str = "") -> list:
        """List objects in a bucket with optional prefix"""
        pass
