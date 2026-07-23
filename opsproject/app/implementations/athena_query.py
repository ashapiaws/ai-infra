import boto3
from typing import List, Dict, Any, Optional
from interfaces.query_engine import QueryEngine


class AthenaQueryEngine(QueryEngine):
    """AWS Athena implementation of QueryEngine"""
    
    def __init__(self, region: str = "us-east-1"):
        self.client = boto3.client('athena', region_name=region)
        self.region = region
    
    async def execute_query(
        self, 
        query: str, 
        database: str = "default",
        output_location: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """Execute query using Athena"""
        if not output_location:
            output_location = f"s3://aws-athena-query-results-{self.region}/"
        
        response = self.client.start_query_execution(
            QueryString=query,
            QueryExecutionContext={'Database': database},
            ResultConfiguration={'OutputLocation': output_location}
        )
        
        query_id = response['QueryExecutionId']
        
        # Wait for query completion
        while True:
            status = await self.get_query_status(query_id)
            if status in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
                break
        
        if status != 'SUCCEEDED':
            raise Exception(f"Query failed with status: {status}")
        
        # Fetch results
        results = self.client.get_query_results(QueryExecutionId=query_id)
        return self._parse_results(results)
    
    async def get_query_status(self, query_id: str) -> str:
        """Get Athena query status"""
        response = self.client.get_query_execution(QueryExecutionId=query_id)
        return response['QueryExecution']['Status']['State']
    
    async def cancel_query(self, query_id: str) -> bool:
        """Cancel Athena query"""
        try:
            self.client.stop_query_execution(QueryExecutionId=query_id)
            return True
        except Exception:
            return False
    
    def _parse_results(self, results: dict) -> List[Dict[str, Any]]:
        """Parse Athena results into list of dicts"""
        rows = results['ResultSet']['Rows']
        if not rows:
            return []
        
        # Extract column names from first row
        columns = [col['VarCharValue'] for col in rows[0]['Data']]
        
        # Parse data rows
        data = []
        for row in rows[1:]:
            values = [col.get('VarCharValue') for col in row['Data']]
            data.append(dict(zip(columns, values)))
        
        return data
