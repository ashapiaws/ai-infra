from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application configuration"""
    
    aws_region: str = "us-east-2"
    athena_output_location: str = ""
    query_engine: str = "athena"  # Can be switched to "trino" later
    
    class Config:
        env_file = ".env"


settings = Settings()
