"""
Athena Query Service for NHL Multi-Agent Analytics System.

This module provides a service for executing SQL queries against Amazon Athena,
managing query lifecycle, implementing result caching, and handling errors.
Includes exponential backoff for query status polling.
"""

import time
import hashlib
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import boto3
from botocore.exceptions import ClientError, BotoCoreError

from app.models import QueryStatus, QueryStatusEnum, AthenaQueryConfig


logger = logging.getLogger(__name__)


class AthenaServiceError(Exception):
    """Base exception for Athena service errors."""
    pass


class QuerySyntaxError(AthenaServiceError):
    """Raised when a SQL query has syntax errors."""
    pass


class QueryTimeoutError(AthenaServiceError):
    """Raised when a query execution times out."""
    pass


class PermissionError(AthenaServiceError):
    """Raised when Athena permissions are insufficient."""
    pass


class AthenaQueryService:
    """
    Service for managing Athena query execution and result retrieval.
    
    Provides methods for executing queries, polling status, retrieving results,
    and caching query results for improved performance.
    """
    
    def __init__(
        self,
        config: AthenaQueryConfig,
        region_name: str = 'us-east-1',
        max_poll_attempts: int = 60,
        initial_poll_interval: float = 1.0,
        max_poll_interval: float = 8.0,
        poll_backoff_multiplier: float = 2.0
    ):
        """
        Initialize the Athena Query Service.
        
        Args:
            config: Athena query configuration
            region_name: AWS region for Athena operations
            max_poll_attempts: Maximum number of status polling attempts
            initial_poll_interval: Initial polling interval in seconds
            max_poll_interval: Maximum polling interval in seconds
            poll_backoff_multiplier: Multiplier for exponential backoff
        """
        self.config = config
        self.region_name = region_name
        self.max_poll_attempts = max_poll_attempts
        self.initial_poll_interval = initial_poll_interval
        self.max_poll_interval = max_poll_interval
        self.poll_backoff_multiplier = poll_backoff_multiplier
        
        # In-memory cache for query results
        # In production, consider using Redis or ElastiCache
        self._result_cache: Dict[str, Dict[str, Any]] = {}
        
        try:
            self.athena_client = boto3.client('athena', region_name=region_name)
            logger.info(f"Athena client initialized for region: {region_name}")
        except Exception as e:
            logger.error(f"Failed to initialize Athena client: {str(e)}")
            raise AthenaServiceError(f"Failed to initialize Athena client: {str(e)}")
    
    def _generate_query_hash(self, sql: str, database: str) -> str:
        """
        Generate a hash for a query to use as cache key.
        
        Args:
            sql: SQL query string
            database: Database name
            
        Returns:
            SHA256 hash of the query
        """
        query_string = f"{database}:{sql}"
        return hashlib.sha256(query_string.encode('utf-8')).hexdigest()
    
    def execute_query(
        self,
        sql: str,
        database: Optional[str] = None
    ) -> str:
        """
        Execute a SQL query on Athena and return the execution ID.
        
        Args:
            sql: SQL query to execute
            database: Database name (uses config default if not provided)
            
        Returns:
            Query execution ID
            
        Raises:
            QuerySyntaxError: If SQL query has syntax errors
            PermissionError: If insufficient permissions
            AthenaServiceError: For other Athena errors
        """
        db = database or self.config.database
        logger.info(f"Executing query on database '{db}': {sql[:100]}...")
        
        try:
            response = self.athena_client.start_query_execution(
                QueryString=sql,
                QueryExecutionContext={'Database': db},
                ResultConfiguration={
                    'OutputLocation': self.config.output_location,
                    'EncryptionConfiguration': {
                        'EncryptionOption': self.config.encryption_option
                    }
                },
                WorkGroup=self.config.workgroup
            )
            
            execution_id = response['QueryExecutionId']
            logger.info(f"Query submitted successfully. Execution ID: {execution_id}")
            return execution_id
            
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', '')
            error_message = e.response.get('Error', {}).get('Message', '')
            
            if error_code in ['InvalidRequestException', 'InvalidParameterException']:
                logger.error(f"Query syntax error: {error_message}")
                raise QuerySyntaxError(f"Query syntax error: {error_message}")
            
            if error_code in ['AccessDeniedException', 'UnauthorizedException']:
                logger.error(f"Permission denied: {error_message}")
                raise PermissionError(f"Permission denied: {error_message}")
            
            logger.error(f"Athena error ({error_code}): {error_message}")
            raise AthenaServiceError(f"Athena error: {error_message}")
            
        except BotoCoreError as e:
            logger.error(f"BotoCore error: {str(e)}")
            raise AthenaServiceError(f"BotoCore error: {str(e)}")
    
    def get_query_status(self, execution_id: str) -> QueryStatus:
        """
        Get the current status of a query execution.
        
        Args:
            execution_id: Query execution ID
            
        Returns:
            QueryStatus object with execution details
            
        Raises:
            AthenaServiceError: If unable to retrieve query status
        """
        logger.debug(f"Getting status for execution ID: {execution_id}")
        
        try:
            response = self.athena_client.get_query_execution(
                QueryExecutionId=execution_id
            )
            
            execution = response['QueryExecution']
            status = execution['Status']
            statistics = execution.get('Statistics', {})
            
            state = status['State']
            state_change_reason = status.get('StateChangeReason')
            submission_time = status.get('SubmissionDateTime', datetime.utcnow())
            completion_time = status.get('CompletionDateTime')
            
            data_scanned_bytes = statistics.get('DataScannedInBytes', 0)
            execution_time_ms = statistics.get('EngineExecutionTimeInMillis', 0)
            
            query_status = QueryStatus(
                execution_id=execution_id,
                state=state,
                state_change_reason=state_change_reason,
                submission_time=submission_time,
                completion_time=completion_time,
                data_scanned_bytes=data_scanned_bytes,
                execution_time_ms=execution_time_ms
            )
            
            logger.debug(f"Query {execution_id} status: {state}")
            return query_status
            
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', '')
            error_message = e.response.get('Error', {}).get('Message', '')
            logger.error(f"Failed to get query status ({error_code}): {error_message}")
            raise AthenaServiceError(f"Failed to get query status: {error_message}")
            
        except BotoCoreError as e:
            logger.error(f"BotoCore error: {str(e)}")
            raise AthenaServiceError(f"BotoCore error: {str(e)}")
    
    def wait_for_query_completion(
        self,
        execution_id: str,
        timeout_seconds: Optional[int] = None
    ) -> QueryStatus:
        """
        Poll query status until completion with exponential backoff.
        
        Args:
            execution_id: Query execution ID
            timeout_seconds: Maximum time to wait (uses max_poll_attempts if not provided)
            
        Returns:
            Final QueryStatus object
            
        Raises:
            QueryTimeoutError: If query doesn't complete within timeout
            AthenaServiceError: If query fails or other errors occur
        """
        logger.info(f"Waiting for query {execution_id} to complete")
        
        poll_interval = self.initial_poll_interval
        start_time = time.time()
        
        for attempt in range(self.max_poll_attempts):
            # Check timeout if specified
            if timeout_seconds and (time.time() - start_time) > timeout_seconds:
                logger.error(f"Query {execution_id} timed out after {timeout_seconds} seconds")
                raise QueryTimeoutError(
                    f"Query timed out after {timeout_seconds} seconds"
                )
            
            status = self.get_query_status(execution_id)
            
            if status.state == QueryStatusEnum.SUCCEEDED.value:
                logger.info(
                    f"Query {execution_id} succeeded after {attempt + 1} polls "
                    f"({status.execution_time_ms}ms execution time)"
                )
                return status
            
            elif status.state == QueryStatusEnum.FAILED.value:
                reason = status.state_change_reason or "Unknown error"
                logger.error(f"Query {execution_id} failed: {reason}")
                raise AthenaServiceError(f"Query failed: {reason}")
            
            elif status.state == QueryStatusEnum.CANCELLED.value:
                logger.warning(f"Query {execution_id} was cancelled")
                raise AthenaServiceError("Query was cancelled")
            
            # Query is still running or queued
            if attempt < self.max_poll_attempts - 1:
                logger.debug(
                    f"Query {execution_id} status: {status.state}. "
                    f"Polling again in {poll_interval:.2f}s..."
                )
                time.sleep(poll_interval)
                
                # Exponential backoff with max limit
                poll_interval = min(
                    poll_interval * self.poll_backoff_multiplier,
                    self.max_poll_interval
                )
        
        # Max attempts reached
        logger.error(f"Query {execution_id} did not complete after {self.max_poll_attempts} polls")
        raise QueryTimeoutError(
            f"Query did not complete after {self.max_poll_attempts} polling attempts"
        )
    
    def get_query_results(
        self,
        execution_id: str,
        max_results: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        Retrieve results from a completed query.
        
        Args:
            execution_id: Query execution ID
            max_results: Maximum number of results to return (uses config default if not provided)
            
        Returns:
            List of result rows as dictionaries
            
        Raises:
            AthenaServiceError: If unable to retrieve results or query not completed
        """
        logger.info(f"Retrieving results for query {execution_id}")
        
        # First check if query is completed
        status = self.get_query_status(execution_id)
        if status.state != QueryStatusEnum.SUCCEEDED.value:
            raise AthenaServiceError(
                f"Cannot retrieve results. Query state is {status.state}"
            )
        
        max_res = max_results or self.config.max_results
        results = []
        next_token = None
        
        try:
            while True:
                # Build request parameters
                params = {
                    'QueryExecutionId': execution_id,
                    'MaxResults': max_res
                }
                if next_token:
                    params['NextToken'] = next_token
                
                response = self.athena_client.get_query_results(**params)
                
                result_set = response.get('ResultSet', {})
                rows = result_set.get('Rows', [])
                
                if not rows:
                    break
                
                # First row contains column names
                if not results:
                    column_info = rows[0]['Data']
                    column_names = [col.get('VarCharValue', '') for col in column_info]
                    rows = rows[1:]  # Skip header row
                else:
                    column_names = list(results[0].keys()) if results else []
                
                # Parse data rows
                for row in rows:
                    row_data = {}
                    for i, col in enumerate(row['Data']):
                        col_name = column_names[i] if i < len(column_names) else f'col_{i}'
                        row_data[col_name] = col.get('VarCharValue')
                    results.append(row_data)
                
                # Check if there are more results
                next_token = response.get('NextToken')
                if not next_token or len(results) >= max_res:
                    break
            
            logger.info(f"Retrieved {len(results)} rows for query {execution_id}")
            return results
            
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', '')
            error_message = e.response.get('Error', {}).get('Message', '')
            logger.error(f"Failed to get query results ({error_code}): {error_message}")
            raise AthenaServiceError(f"Failed to get query results: {error_message}")
            
        except BotoCoreError as e:
            logger.error(f"BotoCore error: {str(e)}")
            raise AthenaServiceError(f"BotoCore error: {str(e)}")
    
    def cancel_query(self, execution_id: str) -> None:
        """
        Cancel a running query.
        
        Args:
            execution_id: Query execution ID
            
        Raises:
            AthenaServiceError: If unable to cancel query
        """
        logger.info(f"Cancelling query {execution_id}")
        
        try:
            self.athena_client.stop_query_execution(
                QueryExecutionId=execution_id
            )
            logger.info(f"Query {execution_id} cancelled successfully")
            
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', '')
            error_message = e.response.get('Error', {}).get('Message', '')
            
            # InvalidRequestException can occur if query already completed
            if error_code == 'InvalidRequestException':
                logger.warning(f"Query {execution_id} may have already completed")
            else:
                logger.error(f"Failed to cancel query ({error_code}): {error_message}")
                raise AthenaServiceError(f"Failed to cancel query: {error_message}")
                
        except BotoCoreError as e:
            logger.error(f"BotoCore error: {str(e)}")
            raise AthenaServiceError(f"BotoCore error: {str(e)}")
    
    def get_cached_results(self, query_hash: str) -> Optional[List[Dict[str, Any]]]:
        """
        Retrieve cached query results if available and not expired.
        
        Args:
            query_hash: Hash of the query (from _generate_query_hash)
            
        Returns:
            Cached results if available and valid, None otherwise
        """
        if query_hash not in self._result_cache:
            logger.debug(f"Cache miss for query hash: {query_hash}")
            return None
        
        cache_entry = self._result_cache[query_hash]
        cached_time = cache_entry['timestamp']
        ttl = timedelta(seconds=self.config.cache_ttl_seconds)
        
        if datetime.utcnow() - cached_time > ttl:
            logger.debug(f"Cache expired for query hash: {query_hash}")
            del self._result_cache[query_hash]
            return None
        
        logger.info(f"Cache hit for query hash: {query_hash}")
        return cache_entry['results']
    
    def cache_results(
        self,
        query_hash: str,
        results: List[Dict[str, Any]],
        ttl: Optional[int] = None
    ) -> None:
        """
        Cache query results with configurable TTL.
        
        Args:
            query_hash: Hash of the query (from _generate_query_hash)
            results: Query results to cache
            ttl: Time-to-live in seconds (uses config default if not provided)
        """
        cache_ttl = ttl or self.config.cache_ttl_seconds
        
        self._result_cache[query_hash] = {
            'results': results,
            'timestamp': datetime.utcnow(),
            'ttl': cache_ttl
        }
        
        logger.info(
            f"Cached {len(results)} results for query hash: {query_hash} "
            f"(TTL: {cache_ttl}s)"
        )
    
    def execute_query_with_cache(
        self,
        sql: str,
        database: Optional[str] = None,
        use_cache: bool = True
    ) -> List[Dict[str, Any]]:
        """
        Execute a query with automatic caching and result retrieval.
        
        This is a convenience method that combines execute_query,
        wait_for_query_completion, and get_query_results with caching.
        
        Args:
            sql: SQL query to execute
            database: Database name (uses config default if not provided)
            use_cache: Whether to use cached results if available
            
        Returns:
            Query results as list of dictionaries
            
        Raises:
            QuerySyntaxError: If SQL query has syntax errors
            QueryTimeoutError: If query execution times out
            PermissionError: If insufficient permissions
            AthenaServiceError: For other Athena errors
        """
        db = database or self.config.database
        query_hash = self._generate_query_hash(sql, db)
        
        # Check cache first
        if use_cache:
            cached_results = self.get_cached_results(query_hash)
            if cached_results is not None:
                return cached_results
        
        # Execute query
        execution_id = self.execute_query(sql, db)
        
        # Wait for completion
        self.wait_for_query_completion(execution_id)
        
        # Get results
        results = self.get_query_results(execution_id)
        
        # Cache results
        if use_cache:
            self.cache_results(query_hash, results)
        
        return results
    
    def clear_cache(self) -> None:
        """Clear all cached query results."""
        cache_size = len(self._result_cache)
        self._result_cache.clear()
        logger.info(f"Cleared {cache_size} cached query results")
    
    def get_cache_stats(self) -> Dict[str, Any]:
        """
        Get statistics about the query result cache.
        
        Returns:
            Dictionary with cache statistics
        """
        total_entries = len(self._result_cache)
        expired_entries = 0
        
        now = datetime.utcnow()
        for entry in self._result_cache.values():
            ttl = timedelta(seconds=entry['ttl'])
            if now - entry['timestamp'] > ttl:
                expired_entries += 1
        
        return {
            'total_entries': total_entries,
            'active_entries': total_entries - expired_entries,
            'expired_entries': expired_entries,
            'cache_ttl_seconds': self.config.cache_ttl_seconds
        }
