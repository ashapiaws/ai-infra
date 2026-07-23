

**Future Write Python Tests **

Testing S3 Upload Endpoint:
curl -X POST "http://localhost:8000/upload?bucket=ads-test-app-2025&key=test.txt" \
  -F "file=@./testfile.txt"

curl -X POST "http://localhost:8000/upload?bucket=my-bucket&key=test.txt" \
  -F "file=@/path/to/file.txt" \
  -F "description=Test file upload" \
  -F "tags=data,test,csv" \
  -F "author=John Doe"

Testing Query Endpoint:

