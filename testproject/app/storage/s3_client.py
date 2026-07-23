"""
S3 Data Access Layer for NHL Multi-Agent Analytics System.

This module provides a client for interacting with S3 buckets, including
methods for uploading files, listing objects, and checking bucket existence.
Implements retry logic with exponential backoff for resilient operations.
"""

import json
import time
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime
import boto3
from botocore.exceptions import ClientError, BotoCoreError


logger = logging.getLogger(__name__)


class S3ClientError(Exception):
    """Base exception for S3 client errors."""
    pass


class BucketUnavailableError(S3ClientError):
    """Raised when an S3 bucket is unavailable."""
    pass


class PermissionDeniedError(S3ClientError):
    """Raised when access to S3 resource is denied."""
    pass


class FileNotFoundError(S3ClientError):
    """Raised when a file is not found in S3."""
    pass


class S3DataClient:
    """
    Client for S3 data operations with retry logic and error handling.
    
    Provides methods for uploading JSON and CSV files, listing bucket contents,
    and checking bucket existence. Implements exponential backoff for transient
    failures.
    """
    
    def __init__(
        self,
        region_name: str = 'us-east-1',
        max_retries: int = 3,
        initial_backoff: float = 1.0,
        backoff_multiplier: float = 2.0
    ):
        """
        Initialize the S3 data client.
        
        Args:
            region_name: AWS region for S3 operations
            max_retries: Maximum number of retry attempts for failed operations
            initial_backoff: Initial backoff delay in seconds
            backoff_multiplier: Multiplier for exponential backoff
        """
        self.region_name = region_name
        self.max_retries = max_retries
        self.initial_backoff = initial_backoff
        self.backoff_multiplier = backoff_multiplier
        
        try:
            self.s3_client = boto3.client('s3', region_name=region_name)
            logger.info(f"S3 client initialized for region: {region_name}")
        except Exception as e:
            logger.error(f"Failed to initialize S3 client: {str(e)}")
            raise S3ClientError(f"Failed to initialize S3 client: {str(e)}")
    
    def _execute_with_retry(self, operation, *args, **kwargs) -> Any:
        """
        Execute an S3 operation with exponential backoff retry logic.
        
        Args:
            operation: The S3 operation function to execute
            *args: Positional arguments for the operation
            **kwargs: Keyword arguments for the operation
            
        Returns:
            The result of the operation
            
        Raises:
            BucketUnavailableError: If bucket is not accessible after retries
            PermissionDeniedError: If access is denied
            S3ClientError: For other S3 errors
        """
        last_exception = None
        backoff = self.initial_backoff
        
        for attempt in range(self.max_retries):
            try:
                result = operation(*args, **kwargs)
                if attempt > 0:
                    logger.info(f"Operation succeeded on attempt {attempt + 1}")
                return result
                
            except ClientError as e:
                error_code = e.response.get('Error', {}).get('Code', '')
                error_message = e.response.get('Error', {}).get('Message', '')
                
                # Handle non-retryable errors immediately
                if error_code in ['NoSuchBucket', 'InvalidBucketName']:
                    logger.error(f"Bucket unavailable: {error_message}")
                    raise BucketUnavailableError(f"Bucket unavailable: {error_message}")
                
                if error_code in ['AccessDenied', 'Forbidden', 'InvalidAccessKeyId', 'SignatureDoesNotMatch']:
                    logger.error(f"Permission denied: {error_message}")
                    raise PermissionDeniedError(f"Permission denied: {error_message}")
                
                if error_code == 'NoSuchKey':
                    logger.error(f"File not found: {error_message}")
                    raise FileNotFoundError(f"File not found: {error_message}")
                
                # Retryable errors
                last_exception = e
                if attempt < self.max_retries - 1:
                    logger.warning(
                        f"Attempt {attempt + 1} failed with {error_code}: {error_message}. "
                        f"Retrying in {backoff:.2f} seconds..."
                    )
                    time.sleep(backoff)
                    backoff *= self.backoff_multiplier
                else:
                    logger.error(f"All {self.max_retries} attempts failed")
                    
            except BotoCoreError as e:
                last_exception = e
                if attempt < self.max_retries - 1:
                    logger.warning(
                        f"Attempt {attempt + 1} failed with BotoCoreError: {str(e)}. "
                        f"Retrying in {backoff:.2f} seconds..."
                    )
                    time.sleep(backoff)
                    backoff *= self.backoff_multiplier
                else:
                    logger.error(f"All {self.max_retries} attempts failed")
        
        # If we get here, all retries failed
        raise S3ClientError(f"Operation failed after {self.max_retries} attempts: {str(last_exception)}")
    
    def write_json_to_bucket(
        self,
        bucket_name: str,
        key: str,
        data: Dict[str, Any],
        metadata: Optional[Dict[str, str]] = None
    ) -> str:
        """
        Write JSON data to an S3 bucket.
        
        Args:
            bucket_name: Name of the S3 bucket
            key: S3 object key (file path)
            data: Dictionary to serialize as JSON
            metadata: Optional metadata to attach to the object
            
        Returns:
            The S3 URI of the uploaded object (s3://bucket/key)
            
        Raises:
            BucketUnavailableError: If bucket is not accessible
            PermissionDeniedError: If access is denied
            S3ClientError: For other S3 errors
        """
        logger.info(f"Writing JSON to s3://{bucket_name}/{key}")
        
        try:
            json_data = json.dumps(data, indent=2, default=str)
        except (TypeError, ValueError) as e:
            logger.error(f"Failed to serialize data to JSON: {str(e)}")
            raise S3ClientError(f"Failed to serialize data to JSON: {str(e)}")
        
        def _put_object():
            put_kwargs = {
                'Bucket': bucket_name,
                'Key': key,
                'Body': json_data.encode('utf-8'),
                'ContentType': 'application/json',
                'ServerSideEncryption': 'AES256'
            }
            
            if metadata:
                put_kwargs['Metadata'] = metadata
            
            return self.s3_client.put_object(**put_kwargs)
        
        self._execute_with_retry(_put_object)
        
        s3_uri = f"s3://{bucket_name}/{key}"
        logger.info(f"Successfully wrote JSON to {s3_uri}")
        return s3_uri
    
    def upload_csv_to_bucket(
        self,
        bucket_name: str,
        key: str,
        file_path: str,
        metadata: Optional[Dict[str, str]] = None
    ) -> str:
        """
        Upload a CSV file to an S3 bucket.
        
        Args:
            bucket_name: Name of the S3 bucket
            key: S3 object key (file path)
            file_path: Local path to the CSV file
            metadata: Optional metadata to attach to the object
            
        Returns:
            The S3 URI of the uploaded object (s3://bucket/key)
            
        Raises:
            BucketUnavailableError: If bucket is not accessible
            PermissionDeniedError: If access is denied
            S3ClientError: For other S3 errors
            FileNotFoundError: If local file doesn't exist
        """
        logger.info(f"Uploading CSV from {file_path} to s3://{bucket_name}/{key}")
        
        # Check if local file exists
        import os
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"Local file not found: {file_path}")
        
        def _upload_file():
            extra_args = {
                'ContentType': 'text/csv',
                'ServerSideEncryption': 'AES256'
            }
            
            if metadata:
                extra_args['Metadata'] = metadata
            
            self.s3_client.upload_file(
                Filename=file_path,
                Bucket=bucket_name,
                Key=key,
                ExtraArgs=extra_args
            )
        
        self._execute_with_retry(_upload_file)
        
        s3_uri = f"s3://{bucket_name}/{key}"
        logger.info(f"Successfully uploaded CSV to {s3_uri}")
        return s3_uri
    
    def list_files(
        self,
        bucket_name: str,
        prefix: str = '',
        max_keys: int = 1000
    ) -> List[Dict[str, Any]]:
        """
        List files in an S3 bucket with optional prefix filter.
        
        Args:
            bucket_name: Name of the S3 bucket
            prefix: Optional prefix to filter objects
            max_keys: Maximum number of keys to return
            
        Returns:
            List of dictionaries containing object metadata:
                - Key: Object key
                - Size: Object size in bytes
                - LastModified: Last modification timestamp
                - ETag: Object ETag
                
        Raises:
            BucketUnavailableError: If bucket is not accessible
            PermissionDeniedError: If access is denied
            S3ClientError: For other S3 errors
        """
        logger.info(f"Listing files in s3://{bucket_name}/{prefix}")
        
        def _list_objects():
            response = self.s3_client.list_objects_v2(
                Bucket=bucket_name,
                Prefix=prefix,
                MaxKeys=max_keys
            )
            return response
        
        response = self._execute_with_retry(_list_objects)
        
        files = []
        if 'Contents' in response:
            for obj in response['Contents']:
                files.append({
                    'Key': obj['Key'],
                    'Size': obj['Size'],
                    'LastModified': obj['LastModified'],
                    'ETag': obj['ETag']
                })
        
        logger.info(f"Found {len(files)} files in s3://{bucket_name}/{prefix}")
        return files
    
    def check_bucket_exists(self, bucket_name: str) -> bool:
        """
        Check if an S3 bucket exists and is accessible.
        
        Args:
            bucket_name: Name of the S3 bucket
            
        Returns:
            True if bucket exists and is accessible, False otherwise
        """
        logger.info(f"Checking if bucket exists: {bucket_name}")
        
        try:
            def _head_bucket():
                return self.s3_client.head_bucket(Bucket=bucket_name)
            
            self._execute_with_retry(_head_bucket)
            logger.info(f"Bucket {bucket_name} exists and is accessible")
            return True
            
        except (BucketUnavailableError, PermissionDeniedError):
            logger.warning(f"Bucket {bucket_name} does not exist or is not accessible")
            return False
        except S3ClientError as e:
            logger.warning(f"Error checking bucket {bucket_name}: {str(e)}")
            return False
    
    def get_object(
        self,
        bucket_name: str,
        key: str
    ) -> bytes:
        """
        Retrieve an object from S3.
        
        Args:
            bucket_name: Name of the S3 bucket
            key: S3 object key
            
        Returns:
            Object content as bytes
            
        Raises:
            BucketUnavailableError: If bucket is not accessible
            PermissionDeniedError: If access is denied
            FileNotFoundError: If object doesn't exist
            S3ClientError: For other S3 errors
        """
        logger.info(f"Getting object s3://{bucket_name}/{key}")
        
        def _get_object():
            response = self.s3_client.get_object(Bucket=bucket_name, Key=key)
            return response['Body'].read()
        
        content = self._execute_with_retry(_get_object)
        logger.info(f"Successfully retrieved object s3://{bucket_name}/{key}")
        return content
    
    def delete_object(
        self,
        bucket_name: str,
        key: str
    ) -> None:
        """
        Delete an object from S3.
        
        Args:
            bucket_name: Name of the S3 bucket
            key: S3 object key
            
        Raises:
            BucketUnavailableError: If bucket is not accessible
            PermissionDeniedError: If access is denied
            S3ClientError: For other S3 errors
        """
        logger.info(f"Deleting object s3://{bucket_name}/{key}")
        
        def _delete_object():
            return self.s3_client.delete_object(Bucket=bucket_name, Key=key)
        
        self._execute_with_retry(_delete_object)
        logger.info(f"Successfully deleted object s3://{bucket_name}/{key}")
