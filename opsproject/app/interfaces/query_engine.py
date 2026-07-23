from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional


class QueryEngine(ABC):
    """Abstract interface for distributed query engines"""
    
    @abstractmethod
    async def execute_query(
        self, 
        query: str, 
        database: str = "default",
        output_location: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Execute a SQL query and return results
        
        Args:
            query: SQL query string
            database: Database/catalog name
            output_location: Optional location for query results
            
        Returns:
            List of dictionaries representing query results
        """
        pass
    
    @abstractmethod
    async def get_query_status(self, query_id: str) -> str:
        """Get the status of a running query"""
        pass
    
    @abstractmethod
    async def cancel_query(self, query_id: str) -> bool:
        """Cancel a running query"""
        pass
