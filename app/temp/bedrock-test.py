#!/usr/bin/env python3
"""
Bedrock Mantle test script to call OpenAI GPT models (5.4, 5.5, 5.6-sol/luna/terra)
via the bedrock-mantle Responses API endpoint using SigV4 authentication.

Uses the Mantle data retention APIs to:
1. GET /v1/data_retention - check account-level data retention config
2. GET /v1/models/{model_id} - check per-model effective mode and allowed_modes
3. POST /v1/responses - invoke the model via the Responses API

All requests signed with SigV4 using the default AWS profile.
"""

import json
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import requests
from datetime import datetime


REGION = "us-east-1"
BASE_URL = f"https://bedrock-mantle.{REGION}.api.aws"


def get_aws_credentials():
    """Get AWS credentials from the default profile."""
    session = boto3.Session(region_name=REGION)
    credentials = session.get_credentials()
    credentials = credentials.get_frozen_credentials()
    return credentials


def sign_request(method, url, headers, body, credentials):
    """Sign a request using SigV4 for the bedrock service."""
    request = AWSRequest(method=method, url=url, headers=headers, data=body)
    SigV4Auth(credentials, "bedrock", REGION).add_auth(request)
    return dict(request.headers)


def mantle_get(path, credentials):
    """Perform a signed GET request to the Mantle API."""
    url = f"{BASE_URL}{path}"
    headers = {"Accept": "application/json"}
    signed_headers = sign_request("GET", url, headers, None, credentials)
    return requests.get(url, headers=signed_headers)


def mantle_post(path, body_dict, credentials):
    """Perform a signed POST request to the Mantle API."""
    url = f"{BASE_URL}{path}"
    body = json.dumps(body_dict)
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    signed_headers = sign_request("POST", url, headers, body, credentials)
    return requests.post(url, headers=signed_headers, data=body)


def print_separator():
    print("\n" + "=" * 80 + "\n")


def print_response(response, label=""):
    """Print full response details: status, headers, body."""
    if label:
        print(f"\n--- {label} ---")
    print(f"  HTTP {response.status_code} {response.reason}")
    print(f"\n  Headers:")
    for key, value in sorted(response.headers.items()):
        print(f"    {key}: {value}")
    print(f"\n  Body:")
    try:
        print(json.dumps(response.json(), indent=4))
    except json.JSONDecodeError:
        print(f"    {response.text}")


def main():
    print("=" * 80)
    print("AWS Bedrock Mantle - OpenAI GPT Model Test")
    print(f"Timestamp: {datetime.now().isoformat()}")
    print(f"Region:    {REGION}")
    print(f"Base URL:  {BASE_URL}")
    print(f"Auth:      SigV4 (default AWS profile)")
    print("=" * 80)

    credentials = get_aws_credentials()

    # -------------------------------------------------------------------------
    # Step 1: Check account-level data retention settings
    # GET /v1/data_retention
    # -------------------------------------------------------------------------
    print_separator()
    print("STEP 1: Account-Level Data Retention Settings")
    print(f"  GET {BASE_URL}/v1/data_retention")
    try:
        resp = mantle_get("/v1/data_retention", credentials)
        print_response(resp)
    except Exception as e:
        print(f"  ERROR: {type(e).__name__}: {e}")

    # -------------------------------------------------------------------------
    # Step 2: Check each model's data retention info and availability
    # GET /v1/models/{model_id}
    # -------------------------------------------------------------------------
    models = [
        "openai.gpt-5.4",
        "openai.gpt-5.5",
        "openai.gpt-5.6-sol",
        "openai.gpt-5.6-luna",
        "openai.gpt-5.6-terra",
    ]

    print_separator()
    print("STEP 2: Per-Model Data Retention & Availability")

    for model_id in models:
        print(f"\n{'─' * 60}")
        print(f"  GET {BASE_URL}/v1/models/{model_id}")
        try:
            resp = mantle_get(f"/v1/models/{model_id}", credentials)
            print_response(resp)
        except Exception as e:
            print(f"  ERROR: {type(e).__name__}: {e}")

    # -------------------------------------------------------------------------
    # Step 3: Invoke each model via the Responses API
    # POST /v1/responses
    # -------------------------------------------------------------------------
    prompt = "What is 2+2? Answer in one sentence."

    print_separator()
    print("STEP 3: Invoke Models via Responses API")
    print(f"  POST {BASE_URL}/v1/responses")
    print(f"  Prompt: \"{prompt}\"")

    for model_id in models:
        print(f"\n{'─' * 60}")
        print(f"  Model: {model_id}")
        try:
            resp = mantle_post("/v1/responses", {
                "model": model_id,
                "input": [
                    {"role": "user", "content": prompt}
                ]
            }, credentials)
            print_response(resp)
        except Exception as e:
            print(f"  ERROR: {type(e).__name__}: {e}")

    print_separator()
    print("Test complete.")


if __name__ == "__main__":
    main()
