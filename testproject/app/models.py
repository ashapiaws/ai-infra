"""
Core data models for NHL Multi-Agent Analytics System.

This module defines the data structures used throughout the system for
representing NHL data, requests, responses, and metadata.
"""

from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import List, Dict, Optional, Union, Any
from enum import Enum


class Position(Enum):
    """NHL player positions."""
    CENTER = "C"
    LEFT_WING = "LW"
    RIGHT_WING = "RW"
    DEFENSE = "D"
    GOALIE = "G"


class QueryStatusEnum(Enum):
    """Athena query execution states."""
    QUEUED = "QUEUED"
    RUNNING = "RUNNING"
    SUCCEEDED = "SUCCEEDED"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"


@dataclass
class PlayerRecord:
    """Represents an NHL player's statistics for a season."""
    player_id: str
    name: str
    team: str
    position: str
    games_played: int
    goals: int
    assists: int
    points: int
    plus_minus: int
    season: str

    def validate(self) -> bool:
        """
        Validate the player record fields.
        
        Returns:
            bool: True if all validations pass
            
        Raises:
            ValueError: If any validation fails
        """
        if not self.player_id or not isinstance(self.player_id, str):
            raise ValueError("player_id must be a non-empty string")
        
        if not self.name or not isinstance(self.name, str):
            raise ValueError("name must be a non-empty string")
        
        if not self.team or not isinstance(self.team, str):
            raise ValueError("team must be a non-empty string")
        
        if not self.position or not isinstance(self.position, str):
            raise ValueError("position must be a non-empty string")
        
        if not isinstance(self.games_played, int) or self.games_played < 0:
            raise ValueError("games_played must be a non-negative integer")
        
        if not isinstance(self.goals, int) or self.goals < 0:
            raise ValueError("goals must be a non-negative integer")
        
        if not isinstance(self.assists, int) or self.assists < 0:
            raise ValueError("assists must be a non-negative integer")
        
        if not isinstance(self.points, int) or self.points < 0:
            raise ValueError("points must be a non-negative integer")
        
        if not isinstance(self.plus_minus, int):
            raise ValueError("plus_minus must be an integer")
        
        if not self.season or not isinstance(self.season, str):
            raise ValueError("season must be a non-empty string")
        
        return True

    def to_dict(self) -> Dict[str, Any]:
        """Convert the player record to a dictionary."""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'PlayerRecord':
        """
        Create a PlayerRecord from a dictionary.
        
        Args:
            data: Dictionary containing player record fields
            
        Returns:
            PlayerRecord instance
        """
        return cls(**data)


@dataclass
class TeamRecord:
    """Represents an NHL team's statistics for a season."""
    team_id: str
    team_name: str
    wins: int
    losses: int
    overtime_losses: int
    points: int
    goals_for: int
    goals_against: int
    season: str

    def validate(self) -> bool:
        """
        Validate the team record fields.
        
        Returns:
            bool: True if all validations pass
            
        Raises:
            ValueError: If any validation fails
        """
        if not self.team_id or not isinstance(self.team_id, str):
            raise ValueError("team_id must be a non-empty string")
        
        if not self.team_name or not isinstance(self.team_name, str):
            raise ValueError("team_name must be a non-empty string")
        
        if not isinstance(self.wins, int) or self.wins < 0:
            raise ValueError("wins must be a non-negative integer")
        
        if not isinstance(self.losses, int) or self.losses < 0:
            raise ValueError("losses must be a non-negative integer")
        
        if not isinstance(self.overtime_losses, int) or self.overtime_losses < 0:
            raise ValueError("overtime_losses must be a non-negative integer")
        
        if not isinstance(self.points, int) or self.points < 0:
            raise ValueError("points must be a non-negative integer")
        
        if not isinstance(self.goals_for, int) or self.goals_for < 0:
            raise ValueError("goals_for must be a non-negative integer")
        
        if not isinstance(self.goals_against, int) or self.goals_against < 0:
            raise ValueError("goals_against must be a non-negative integer")
        
        if not self.season or not isinstance(self.season, str):
            raise ValueError("season must be a non-empty string")
        
        return True

    def to_dict(self) -> Dict[str, Any]:
        """Convert the team record to a dictionary."""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'TeamRecord':
        """
        Create a TeamRecord from a dictionary.
        
        Args:
            data: Dictionary containing team record fields
            
        Returns:
            TeamRecord instance
        """
        return cls(**data)


@dataclass
class QueryRequest:
    """Represents a user query request."""
    query_text: str
    user_id: str
    session_id: str
    timestamp: datetime = field(default_factory=datetime.utcnow)

    def validate(self) -> bool:
        """
        Validate the query request fields.
        
        Returns:
            bool: True if all validations pass
            
        Raises:
            ValueError: If any validation fails
        """
        if not self.query_text or not isinstance(self.query_text, str):
            raise ValueError("query_text must be a non-empty string")
        
        if not self.user_id or not isinstance(self.user_id, str):
            raise ValueError("user_id must be a non-empty string")
        
        if not self.session_id or not isinstance(self.session_id, str):
            raise ValueError("session_id must be a non-empty string")
        
        if not isinstance(self.timestamp, datetime):
            raise ValueError("timestamp must be a datetime object")
        
        return True

    def to_dict(self) -> Dict[str, Any]:
        """Convert the query request to a dictionary."""
        data = asdict(self)
        data['timestamp'] = self.timestamp.isoformat()
        return data

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'QueryRequest':
        """
        Create a QueryRequest from a dictionary.
        
        Args:
            data: Dictionary containing query request fields
            
        Returns:
            QueryRequest instance
        """
        data_copy = data.copy()
        if 'timestamp' in data_copy and isinstance(data_copy['timestamp'], str):
            data_copy['timestamp'] = datetime.fromisoformat(data_copy['timestamp'])
        return cls(**data_copy)


@dataclass
class QueryResult:
    """Represents the result of a query operation."""
    data: List[Union[PlayerRecord, TeamRecord]]
    query_interpretation: str
    record_count: int
    execution_time_ms: int
    success: bool
    error_message: Optional[str] = None

    def validate(self) -> bool:
        """
        Validate the query result fields.
        
        Returns:
            bool: True if all validations pass
            
        Raises:
            ValueError: If any validation fails
        """
        if not isinstance(self.data, list):
            raise ValueError("data must be a list")
        
        for record in self.data:
            if not isinstance(record, (PlayerRecord, TeamRecord)):
                raise ValueError("data must contain only PlayerRecord or TeamRecord instances")
        
        if not self.query_interpretation or not isinstance(self.query_interpretation, str):
            raise ValueError("query_interpretation must be a non-empty string")
        
        if not isinstance(self.record_count, int) or self.record_count < 0:
            raise ValueError("record_count must be a non-negative integer")
        
        if not isinstance(self.execution_time_ms, int) or self.execution_time_ms < 0:
            raise ValueError("execution_time_ms must be a non-negative integer")
        
        if not isinstance(self.success, bool):
            raise ValueError("success must be a boolean")
        
        if self.error_message is not None and not isinstance(self.error_message, str):
            raise ValueError("error_message must be a string or None")
        
        return True

    def to_dict(self) -> Dict[str, Any]:
        """Convert the query result to a dictionary."""
        return {
            'data': [record.to_dict() for record in self.data],
            'query_interpretation': self.query_interpretation,
            'record_count': self.record_count,
            'execution_time_ms': self.execution_time_ms,
            'success': self.success,
            'error_message': self.error_message
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'QueryResult':
        """
        Create a QueryResult from a dictionary.
        
        Args:
            data: Dictionary containing query result fields
            
        Returns:
            QueryResult instance
        """
        data_copy = data.copy()
        
        # Convert data list to appropriate record types
        records = []
        for record_dict in data_copy.get('data', []):
            # Determine record type based on fields
            if 'player_id' in record_dict:
                records.append(PlayerRecord.from_dict(record_dict))
            elif 'team_id' in record_dict:
                records.append(TeamRecord.from_dict(record_dict))
        
        data_copy['data'] = records
        return cls(**data_copy)


@dataclass
class PredictionRequest:
    """Represents a prediction request."""
    prediction_type: str
    parameters: Dict[str, Any]
    user_id: str
    session_id: str
    timestamp: datetime = field(default_factory=datetime.utcnow)

    def validate(self) -> bool:
        """
        Validate the prediction request fields.
        
        Returns:
            bool: True if all validations pass
            
        Raises:
            ValueError: If any validation fails
        """
        if not self.prediction_type or not isinstance(self.prediction_type, str):
            raise ValueError("prediction_type must be a non-empty string")
        
        if not isinstance(self.parameters, dict):
            raise ValueError("parameters must be a dictionary")
        
        if not self.user_id or not isinstance(self.user_id, str):
            raise ValueError("user_id must be a non-empty string")
        
        if not self.session_id or not isinstance(self.session_id, str):
            raise ValueError("session_id must be a non-empty string")
        
        if not isinstance(self.timestamp, datetime):
            raise ValueError("timestamp must be a datetime object")
        
        return True

    def to_dict(self) -> Dict[str, Any]:
        """Convert the prediction request to a dictionary."""
        data = asdict(self)
        data['timestamp'] = self.timestamp.isoformat()
        return data

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'PredictionRequest':
        """
        Create a PredictionRequest from a dictionary.
        
        Args:
            data: Dictionary containing prediction request fields
            
        Returns:
            PredictionRequest instance
        """
        data_copy = data.copy()
        if 'timestamp' in data_copy and isinstance(data_copy['timestamp'], str):
            data_copy['timestamp'] = datetime.fromisoformat(data_copy['timestamp'])
        return cls(**data_copy)


@dataclass
class ConfidenceMetrics:
    """Represents confidence metrics for a prediction."""
    overall_confidence: float
    data_quality_score: float
    model_certainty: float
    sample_size: int

    def validate(self) -> bool:
        """
        Validate the confidence metrics fields.
        
        Returns:
            bool: True if all validations pass
            
        Raises:
            ValueError: If any validation fails
        """
        if not isinstance(self.overall_confidence, (int, float)):
            raise ValueError("overall_confidence must be a number")
        
        if not 0.0 <= self.overall_confidence <= 1.0:
            raise ValueError("overall_confidence must be between 0.0 and 1.0")
        
        if not isinstance(self.data_quality_score, (int, float)):
            raise ValueError("data_quality_score must be a number")
        
        if not 0.0 <= self.data_quality_score <= 1.0:
            raise ValueError("data_quality_score must be between 0.0 and 1.0")
        
        if not isinstance(self.model_certainty, (int, float)):
            raise ValueError("model_certainty must be a number")
        
        if not 0.0 <= self.model_certainty <= 1.0:
            raise ValueError("model_certainty must be between 0.0 and 1.0")
        
        if not isinstance(self.sample_size, int) or self.sample_size < 0:
            raise ValueError("sample_size must be a non-negative integer")
        
        return True

    def to_dict(self) -> Dict[str, Any]:
        """Convert the confidence metrics to a dictionary."""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ConfidenceMetrics':
        """
        Create ConfidenceMetrics from a dictionary.
        
        Args:
            data: Dictionary containing confidence metrics fields
            
        Returns:
            ConfidenceMetrics instance
        """
        return cls(**data)


@dataclass
class PredictionResult:
    """Represents the result of a prediction operation."""
    prediction_id: str
    prediction_type: str
    input_parameters: Dict[str, Any]
    prediction_output: Dict[str, Any]
    confidence_metrics: ConfidenceMetrics
    data_sources: List[str]
    timestamp: datetime
    user_id: str

    def validate(self) -> bool:
        """
        Validate the prediction result fields.
        
        Returns:
            bool: True if all validations pass
            
        Raises:
            ValueError: If any validation fails
        """
        if not self.prediction_id or not isinstance(self.prediction_id, str):
            raise ValueError("prediction_id must be a non-empty string")
        
        if not self.prediction_type or not isinstance(self.prediction_type, str):
            raise ValueError("prediction_type must be a non-empty string")
        
        if not isinstance(self.input_parameters, dict):
            raise ValueError("input_parameters must be a dictionary")
        
        if not isinstance(self.prediction_output, dict):
            raise ValueError("prediction_output must be a dictionary")
        
        if not isinstance(self.confidence_metrics, ConfidenceMetrics):
            raise ValueError("confidence_metrics must be a ConfidenceMetrics instance")
        
        # Validate confidence metrics
        self.confidence_metrics.validate()
        
        if not isinstance(self.data_sources, list):
            raise ValueError("data_sources must be a list")
        
        for source in self.data_sources:
            if not isinstance(source, str):
                raise ValueError("data_sources must contain only strings")
        
        if not isinstance(self.timestamp, datetime):
            raise ValueError("timestamp must be a datetime object")
        
        if not self.user_id or not isinstance(self.user_id, str):
            raise ValueError("user_id must be a non-empty string")
        
        return True

    def to_dict(self) -> Dict[str, Any]:
        """Convert the prediction result to a dictionary."""
        return {
            'prediction_id': self.prediction_id,
            'prediction_type': self.prediction_type,
            'input_parameters': self.input_parameters,
            'prediction_output': self.prediction_output,
            'confidence_metrics': self.confidence_metrics.to_dict(),
            'data_sources': self.data_sources,
            'timestamp': self.timestamp.isoformat(),
            'user_id': self.user_id
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'PredictionResult':
        """
        Create a PredictionResult from a dictionary.
        
        Args:
            data: Dictionary containing prediction result fields
            
        Returns:
            PredictionResult instance
        """
        data_copy = data.copy()
        
        # Convert confidence_metrics
        if 'confidence_metrics' in data_copy and isinstance(data_copy['confidence_metrics'], dict):
            data_copy['confidence_metrics'] = ConfidenceMetrics.from_dict(data_copy['confidence_metrics'])
        
        # Convert timestamp
        if 'timestamp' in data_copy and isinstance(data_copy['timestamp'], str):
            data_copy['timestamp'] = datetime.fromisoformat(data_copy['timestamp'])
        
        return cls(**data_copy)


@dataclass
class ErrorResponse:
    """Represents an error response."""
    error_code: str
    error_message: str
    user_message: str
    timestamp: datetime
    request_id: str
    retry_possible: bool

    def validate(self) -> bool:
        """
        Validate the error response fields.
        
        Returns:
            bool: True if all validations pass
            
        Raises:
            ValueError: If any validation fails
        """
        if not self.error_code or not isinstance(self.error_code, str):
            raise ValueError("error_code must be a non-empty string")
        
        if not self.error_message or not isinstance(self.error_message, str):
            raise ValueError("error_message must be a non-empty string")
        
        if not self.user_message or not isinstance(self.user_message, str):
            raise ValueError("user_message must be a non-empty string")
        
        if not isinstance(self.timestamp, datetime):
            raise ValueError("timestamp must be a datetime object")
        
        if not self.request_id or not isinstance(self.request_id, str):
            raise ValueError("request_id must be a non-empty string")
        
        if not isinstance(self.retry_possible, bool):
            raise ValueError("retry_possible must be a boolean")
        
        return True

    def to_dict(self) -> Dict[str, Any]:
        """Convert the error response to a dictionary."""
        data = asdict(self)
        data['timestamp'] = self.timestamp.isoformat()
        return data

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ErrorResponse':
        """
        Create an ErrorResponse from a dictionary.
        
        Args:
            data: Dictionary containing error response fields
            
        Returns:
            ErrorResponse instance
        """
        data_copy = data.copy()
        if 'timestamp' in data_copy and isinstance(data_copy['timestamp'], str):
            data_copy['timestamp'] = datetime.fromisoformat(data_copy['timestamp'])
        return cls(**data_copy)


@dataclass
class QueryStatus:
    """Represents the status of an Athena query execution."""
    execution_id: str
    state: str
    state_change_reason: Optional[str]
    submission_time: datetime
    completion_time: Optional[datetime]
    data_scanned_bytes: int
    execution_time_ms: int

    def validate(self) -> bool:
        """
        Validate the query status fields.
        
        Returns:
            bool: True if all validations pass
            
        Raises:
            ValueError: If any validation fails
        """
        if not self.execution_id or not isinstance(self.execution_id, str):
            raise ValueError("execution_id must be a non-empty string")
        
        if not self.state or not isinstance(self.state, str):
            raise ValueError("state must be a non-empty string")
        
        valid_states = [s.value for s in QueryStatusEnum]
        if self.state not in valid_states:
            raise ValueError(f"state must be one of {valid_states}")
        
        if self.state_change_reason is not None and not isinstance(self.state_change_reason, str):
            raise ValueError("state_change_reason must be a string or None")
        
        if not isinstance(self.submission_time, datetime):
            raise ValueError("submission_time must be a datetime object")
        
        if self.completion_time is not None and not isinstance(self.completion_time, datetime):
            raise ValueError("completion_time must be a datetime object or None")
        
        if not isinstance(self.data_scanned_bytes, int) or self.data_scanned_bytes < 0:
            raise ValueError("data_scanned_bytes must be a non-negative integer")
        
        if not isinstance(self.execution_time_ms, int) or self.execution_time_ms < 0:
            raise ValueError("execution_time_ms must be a non-negative integer")
        
        return True

    def to_dict(self) -> Dict[str, Any]:
        """Convert the query status to a dictionary."""
        return {
            'execution_id': self.execution_id,
            'state': self.state,
            'state_change_reason': self.state_change_reason,
            'submission_time': self.submission_time.isoformat(),
            'completion_time': self.completion_time.isoformat() if self.completion_time else None,
            'data_scanned_bytes': self.data_scanned_bytes,
            'execution_time_ms': self.execution_time_ms
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'QueryStatus':
        """
        Create a QueryStatus from a dictionary.
        
        Args:
            data: Dictionary containing query status fields
            
        Returns:
            QueryStatus instance
        """
        data_copy = data.copy()
        
        if 'submission_time' in data_copy and isinstance(data_copy['submission_time'], str):
            data_copy['submission_time'] = datetime.fromisoformat(data_copy['submission_time'])
        
        if 'completion_time' in data_copy and data_copy['completion_time'] is not None:
            if isinstance(data_copy['completion_time'], str):
                data_copy['completion_time'] = datetime.fromisoformat(data_copy['completion_time'])
        
        return cls(**data_copy)


@dataclass
class AthenaQueryConfig:
    """Configuration for Athena query execution."""
    database: str
    workgroup: str
    output_location: str
    encryption_option: str
    max_results: int = 1000
    cache_ttl_seconds: int = 3600

    def validate(self) -> bool:
        """
        Validate the Athena query configuration fields.
        
        Returns:
            bool: True if all validations pass
            
        Raises:
            ValueError: If any validation fails
        """
        if not self.database or not isinstance(self.database, str):
            raise ValueError("database must be a non-empty string")
        
        if not self.workgroup or not isinstance(self.workgroup, str):
            raise ValueError("workgroup must be a non-empty string")
        
        if not self.output_location or not isinstance(self.output_location, str):
            raise ValueError("output_location must be a non-empty string")
        
        if not self.encryption_option or not isinstance(self.encryption_option, str):
            raise ValueError("encryption_option must be a non-empty string")
        
        if not isinstance(self.max_results, int) or self.max_results <= 0:
            raise ValueError("max_results must be a positive integer")
        
        if not isinstance(self.cache_ttl_seconds, int) or self.cache_ttl_seconds < 0:
            raise ValueError("cache_ttl_seconds must be a non-negative integer")
        
        return True

    def to_dict(self) -> Dict[str, Any]:
        """Convert the Athena query config to a dictionary."""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'AthenaQueryConfig':
        """
        Create an AthenaQueryConfig from a dictionary.
        
        Args:
            data: Dictionary containing Athena query config fields
            
        Returns:
            AthenaQueryConfig instance
        """
        return cls(**data)
