import boto3
from typing import Optional
from interfaces.storage import StorageService


class S3StorageService(StorageService):
    """AWS S3 implementation of StorageService"""
    
    def __init__(self, region: str = "us-east-1"):
        self.client = boto3.client('s3', region_name=region)
        self.region = region
    
    async def upload(
        self, 
        bucket: str, 
        key: str, 
        data: bytes,
        metadata: Optional[dict] = None
    ) -> str:
        """Upload data to S3 with metadata and tags"""
        extra_args = {}
        
        # Add user-defined metadata
        if metadata:
            # Separate tags from other metadata
            tags = metadata.pop('tags', None)
            
            # Add remaining metadata as S3 metadata
            if metadata:
                extra_args['Metadata'] = {k: str(v) for k, v in metadata.items() if v is not None}
            
            # Add tags if provided
            if tags and isinstance(tags, list):
                tag_string = '&'.join([f"{i}=tag{i}" for i in range(len(tags))])
                extra_args['Tagging'] = tag_string
        
        self.client.put_object(
            Bucket=bucket,
            Key=key,
            Body=data,
            **extra_args
        )
        
        return f"s3://{bucket}/{key}"
    
    async def download(self, bucket: str, key: str) -> bytes:
        """Download data from S3"""
        response = self.client.get_object(Bucket=bucket, Key=key)
        return response['Body'].read()
    
    async def delete(self, bucket: str, key: str) -> bool:
        """Delete object from S3"""
        try:
            self.client.delete_object(Bucket=bucket, Key=key)
            return True
        except Exception:
            return False
    
    async def list_objects(self, bucket: str, prefix: str = "") -> list:
        """List objects in S3 bucket"""
        response = self.client.list_objects_v2(Bucket=bucket, Prefix=prefix)
        
        if 'Contents' not in response:
            return []
        
        return [
            {
                'key': obj['Key'],
                'size': obj['Size'],
                'last_modified': obj['LastModified'].isoformat()
            }
            for obj in response['Contents']
        ]
